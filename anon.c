/*
 * PostgreSQL Anonymizer
 *
 */

#include "postgres.h"

#if PG_VERSION_NUM >= 120000
#include "access/relation.h"
#include "access/table.h"
#else
#include "access/heapam.h"
#include "access/htup_details.h"
#endif

#include "access/xact.h"
#include "commands/seclabel.h"
#include "parser/analyze.h"
#include "parser/parser.h"
#include "fmgr.h"
#include "catalog/pg_attrdef.h"
#if PG_VERSION_NUM >= 110000
#include "catalog/pg_attrdef_d.h"
#endif
#include "catalog/pg_authid.h"
#include "catalog/pg_class.h"
#include "catalog/pg_database.h"
#include "catalog/pg_namespace.h"
#include "catalog/namespace.h"
#include "miscadmin.h"
#include "utils/acl.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/ruleutils.h"
#include "utils/varlena.h"

PG_MODULE_MAGIC;

/* Saved hook values in case of unload */
static post_parse_analyze_hook_type prev_post_parse_analyze_hook = NULL;

/*
 * External Functions
 */
PGDLLEXPORT Datum   anon_get_function_schema(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum   anon_init(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum   anon_masking_expressions_for_table(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum   anon_masking_value_for_column(PG_FUNCTION_ARGS);
PGDLLEXPORT void    _PG_init(void);
PGDLLEXPORT void    _PG_fini(void);

PG_FUNCTION_INFO_V1(anon_get_function_schema);
PG_FUNCTION_INFO_V1(anon_init);
PG_FUNCTION_INFO_V1(anon_masking_expressions_for_table);
PG_FUNCTION_INFO_V1(anon_masking_value_for_column);

/*
 * GUC Parameters
 */

static char * guc_anon_k_anonymity_provider;
static char * guc_anon_masking_policies;
static bool   guc_anon_privacy_by_default;
static bool   guc_anon_restrict_to_trusted_schemas;
static bool   guc_anon_strict_mode;

// Some GUC vars below are not used in the C code
// but they are used in the plpgsql code
// compile with `-Wno-unused-variable` to avoid warnings
static char *guc_anon_algorithm;
static char *guc_anon_mask_schema;
static char *guc_anon_salt;
static char *guc_anon_source_schema;
static bool guc_anon_transparent_dynamic_masking;

/*
 * Internal Functions
 */
static bool   pa_check_masking_policies(char **newval, void **extra, GucSource source);
static char * pa_get_masking_policy_for_role(Oid roleid);
static void   pa_masking_policy_object_relabel(const ObjectAddress *object, const char *seclabel);
static bool   pa_has_mask_in_policy(Oid roleid, char *policy);
static void   pa_rewrite(Query * query, char * policy);
static char * pa_cast_as_regtype(char * value, int atttypid);
static char * pa_masking_value_for_att(Relation rel, FormData_pg_attribute * att, char * policy);

#if PG_VERSION_NUM >= 140000
static void   pa_post_parse_analyze_hook(ParseState *pstate, Query *query, JumbleState *jstate);
#else
static void   pa_post_parse_analyze_hook(ParseState *pstate, Query *query);
#endif

/*
 * Checking the syntax of the masking rules
 */
static void
pa_masking_policy_object_relabel(const ObjectAddress *object, const char *seclabel)
{
  char *checksemicolon;

  /* SECURITY LABEL FOR anon ON COLUMN foo.bar IS NULL */
  if (seclabel == NULL) return;

  /* Prevent SQL injection attacks inside the security label */
  checksemicolon = strchr(seclabel, ';');

  switch (object->classId)
  {
    /* SECURITY LABEL FOR anon ON DATABASE d IS 'TABLESAMPLE SYSTEM(10)' */
    case DatabaseRelationId:

      if ( pg_strncasecmp(seclabel, "TABLESAMPLE", 11) == 0
        && checksemicolon == NULL
      )
        return;

      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
         errmsg("'%s' is not a valid label for a database", seclabel)));
      break;

    case RelationRelationId:

      /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
      if (object->objectSubId == 0)
      {
        if ( pg_strncasecmp(seclabel, "TABLESAMPLE", 11) == 0
          && checksemicolon == NULL
        )
          return;

        ereport(ERROR,
          (errcode(ERRCODE_INVALID_NAME),
           errmsg("'%s' is not a valid label for a table", seclabel)));
      }

      /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
      if ( pg_strncasecmp(seclabel, "MASKED WITH FUNCTION", 20) == 0
        || pg_strncasecmp(seclabel, "MASKED WITH VALUE", 17) == 0
        || pg_strncasecmp(seclabel, "NOT MASKED", 10) == 0
      )
        return;

      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
         errmsg("'%s' is not a valid label for a column", seclabel)));
      break;

    /* SECURITY LABEL FOR anon ON ROLE batman IS 'MASKED' */
    case AuthIdRelationId:
      if (pg_strcasecmp(seclabel,"MASKED") == 0)
        return;

      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
         errmsg("'%s' is not a valid label for a role", seclabel)));
      break;

    /* SECURITY LABEL FOR anon ON SCHEMA public IS 'TRUSTED' */
    case NamespaceRelationId:
      if (!superuser())
        ereport(ERROR,
            (errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
             errmsg("only superuser can set an anon label for a schema")));

      if (pg_strcasecmp(seclabel,"TRUSTED") == 0)
        return;

      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
         errmsg("'%s' is not a valid label for a schema", seclabel)));
      break;

    /* everything else is unsupported */
    default:
      ereport(ERROR,
          (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
           errmsg("The anon extension does not support labels on this object")));
      break;
  }

  ereport(ERROR,
      (errcode(ERRCODE_INVALID_NAME),
       errmsg("'%s' is not a valid label", seclabel)));
}

/*
 * Checking the syntax of the k-anonymity declarations
 */
static void
pa_k_anonymity_object_relabel(const ObjectAddress *object, const char *seclabel)
{
  switch (object->classId)
  {

    case RelationRelationId:
      /* SECURITY LABEL FOR k_anonymity ON COLUMN t.i IS 'INDIRECT IDENTIFIER' */
      if ( pg_strncasecmp(seclabel, "QUASI IDENTIFIER",17) == 0
        || pg_strncasecmp(seclabel, "INDIRECT IDENTIFIER",19) == 0
      )
      return;

      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
         errmsg("'%s' is not a valid label for a column", seclabel)));
      break;

    /* everything else is unsupported */
    default:
      ereport(ERROR,
          (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
           errmsg("The k_anonymity provider does not support labels on this object")));
      break;
  }

  ereport(ERROR,
      (errcode(ERRCODE_INVALID_NAME),
       errmsg("'%s' is not a valid label", seclabel)));
}

/*
 * Register the extension and declare its GUC variables
 */
void
_PG_init(void)
{
  List *      masking_policies;
  ListCell *  c;
  char *      dup;

  /* GUC parameters */
  DefineCustomStringVariable
  (
    "anon.algorithm",
    "The hash method used for pseudonymizing functions",
    "",
    &guc_anon_algorithm,
    "sha256",
    PGC_SUSET,
    GUC_SUPERUSER_ONLY,
    NULL,
    NULL,
    NULL
  );

  DefineCustomStringVariable
  (
    "anon.k_anonymity_provider",
    "The security label provider used for k-anonymity",
    "",
    &guc_anon_k_anonymity_provider,
    "k_anonymity",
    PGC_SUSET,
    GUC_SUPERUSER_ONLY,
    NULL,
    NULL,
    NULL
  );

  DefineCustomStringVariable
  (
    "anon.masking_policies",
    "Define multiple masking policies (NOT IMPLEMENTED YET)",
    "",
    &guc_anon_masking_policies,
    "anon",
    PGC_SUSET,
    GUC_LIST_INPUT | GUC_SUPERUSER_ONLY,
    pa_check_masking_policies,
    NULL,
    NULL
  );

  DefineCustomStringVariable
  (
    "anon.maskschema",
    "The schema where the dynamic masking views are stored",
    "",
    &guc_anon_mask_schema,
    "mask",
    PGC_SUSET,
    0,
    NULL,
    NULL,
    NULL
  );

  DefineCustomBoolVariable
  (
    "anon.privacy_by_default",
    "Mask all columns with NULL (or the default value for NOT NULL columns).",
    "",
    &guc_anon_privacy_by_default,
    false,
    PGC_SUSET,
    0,
    NULL,
    NULL,
    NULL
  );

  DefineCustomBoolVariable
  (
    "anon.restrict_to_trusted_schemas",
    "Masking filters must be in a trusted schema",
    "Activate this option to prevent non-superuser from using their own masking filters",
    &guc_anon_restrict_to_trusted_schemas,
    false,
    PGC_SUSET,
    GUC_SUPERUSER_ONLY,
    NULL,
    NULL,
    NULL
  );

  DefineCustomStringVariable
  (
    "anon.salt",
    "The salt value used for the pseudonymizing functions",
    "",
    &guc_anon_salt,
    "",
    PGC_SUSET,
    GUC_SUPERUSER_ONLY,
    NULL,
    NULL,
    NULL
  );

  DefineCustomStringVariable
  (
    "anon.sourceschema",
    "The schema where the table are masked by the dynamic masking engine",
    "",
    &guc_anon_source_schema,
    "public",
    PGC_SUSET,
    0,
    NULL,
    NULL,
    NULL
  );

  DefineCustomBoolVariable
  (
    "anon.strict_mode",
    "A masking rule cannot change a column data type, unless you disable this",
    "Disabling the mode is not recommended",
    &guc_anon_strict_mode,
    true,
    PGC_SUSET,
    0,
    NULL,
    NULL,
    NULL
  );

  DefineCustomBoolVariable
  (
    "anon.transparent_dynamic_masking",
    "New masking engine (EXPERIMENTAL)",
    "",
    &guc_anon_transparent_dynamic_masking,
    false,
    PGC_SUSET,
    0,
    NULL,
    NULL,
    NULL
  );

  /* Register the security label provider for k-anonymity */
  register_label_provider(guc_anon_k_anonymity_provider,
                          pa_k_anonymity_object_relabel
  );

  /* Register a security label provider for each masking policy */
  dup = pstrdup(guc_anon_masking_policies);
  SplitGUCList(dup, ',', &masking_policies);
  foreach(c,masking_policies)
  {
    const char      *pg_catalog = "pg_catalog";
    ObjectAddress   schema;
    Oid             schema_id;
    char            *policy = (char *) lfirst(c);

    register_label_provider(policy,pa_masking_policy_object_relabel);

  }

  /* Install the hooks */
  prev_post_parse_analyze_hook = post_parse_analyze_hook;
  post_parse_analyze_hook = pa_post_parse_analyze_hook;
}

/*
 * Unregister and restore the hook
 */
void
_PG_fini(void) {
  post_parse_analyze_hook = prev_post_parse_analyze_hook;
}

/*
 * anon_init
 *   Initialize the extension
 *
 */
Datum
anon_init(PG_FUNCTION_ARGS)
{
  List *      masking_policies;
  ListCell *  m;
  char *      dup;

  /*
   * In each masking policy, mark `anon` and `pg_catalog` as TRUSTED
   * For some reasons, this can't be done in _PG_init()
   */
  dup = pstrdup(guc_anon_masking_policies);
  SplitGUCList(dup, ',', &masking_policies);
  foreach(m,masking_policies)
  {
    ObjectAddress   anon_schema;
    ObjectAddress   pg_catalog_schema;
    Oid             schema_id;
    char            *policy = (char *) lfirst(m);
    char            *seclabel = NULL;

    register_label_provider(policy,pa_masking_policy_object_relabel);

    schema_id=get_namespace_oid("anon",false);
    ObjectAddressSet(anon_schema, NamespaceRelationId, schema_id);
    seclabel = GetSecurityLabel(&anon_schema, policy);
    if ( ! seclabel || pg_strcasecmp(seclabel,"TRUSTED") != 0)
      SetSecurityLabel(&anon_schema,policy,"TRUSTED");

    schema_id=get_namespace_oid("pg_catalog",false);
    ObjectAddressSet(pg_catalog_schema, NamespaceRelationId, schema_id);
    seclabel = GetSecurityLabel(&pg_catalog_schema, policy);
    if ( ! seclabel || pg_strcasecmp(seclabel,"TRUSTED") != 0)
      SetSecurityLabel(&pg_catalog_schema,policy,"TRUSTED");
  }

  PG_RETURN_BOOL(true);
}

/*
 * pa_cast_as_regtype
 *   decorates a value with a CAST function
 */
static char *
pa_cast_as_regtype(char * value, int atttypid)
{
  StringInfoData casted_value;
  initStringInfo(&casted_value);
  appendStringInfo(&casted_value, "CAST(%s AS %d::REGTYPE)", value, atttypid);
  return casted_value.data;
}

/*
 * anon_get_function_schema
 *   Given a function call, e.g. 'anon.fake_city()', returns the namespace of
 *   the function (if possible)
 *
 * returns the schema name if the function is properly schema-qualified
 * returns an empty string if we can't find the schema name
 *
 * We're calling the parser to split the function call into a "raw parse tree".
 * At this stage, there's no way to know if the schema does really exists. We
 * simply deduce the schema name as it is provided.
 *
 */

Datum
anon_get_function_schema(PG_FUNCTION_ARGS)
{
    bool input_is_null = PG_ARGISNULL(0);
    char* function_call= text_to_cstring(PG_GETARG_TEXT_PP(0));
    char query_string[1024];
    List  *raw_parsetree_list;
    SelectStmt *stmt;
    ResTarget  *restarget;
    FuncCall   *fc;

    if (input_is_null) PG_RETURN_NULL();

    /* build a simple SELECT statement and parse it */
    query_string[0] = '\0';
    strlcat(query_string, "SELECT ", sizeof(query_string));
    strlcat(query_string, function_call, sizeof(query_string));
    #if PG_VERSION_NUM >= 140000
    raw_parsetree_list = raw_parser(query_string,RAW_PARSE_DEFAULT);
    #else
    raw_parsetree_list = raw_parser(query_string);
    #endif

    /* walk throught the parse tree, down to the FuncCall node (if present) */
    #if PG_VERSION_NUM >= 100000
    stmt = (SelectStmt *) linitial_node(RawStmt, raw_parsetree_list)->stmt;
    #else
    stmt = (SelectStmt *) linitial(raw_parsetree_list);
    #endif
    restarget = (ResTarget *) linitial(stmt->targetList);
    if (! IsA(restarget->val, FuncCall))
    {
      ereport(ERROR,
        (errcode(ERRCODE_INVALID_NAME),
        errmsg("'%s' is not a valid function call", function_call)));
    }

    /* if the function name is qualified, extract and return the schema name */
    fc = (FuncCall *) restarget->val;
    if ( list_length(fc->funcname) == 2 )
    {
      PG_RETURN_TEXT_P(cstring_to_text(strVal(linitial(fc->funcname))));
    }

    PG_RETURN_TEXT_P(cstring_to_text(""));
}


/*
 * pa_check_masking_policies
 *   A validation function (hook) called when `anon.masking_policies` is set.
 *
 * see: https://github.com/postgres/postgres/blob/REL_15_STABLE/src/backend/commands/variable.c#L44
 */
static bool
pa_check_masking_policies(char **newval, void **extra, GucSource source)
{
  char    *rawstring;
  List    *elemlist;

  if (!*newval ||  strlen(*newval) == 0 )
  {
    GUC_check_errdetail("anon.masking_policies cannot be NULL or empty");
    return false;
  }

  /* Need a modifiable copy of string */
  rawstring = pstrdup(*newval);

  /* Parse string into list of identifiers */
  if (!SplitIdentifierString(rawstring, ',', &elemlist))
  {
    /* syntax error in list */
    GUC_check_errdetail("List syntax is invalid.");
    pfree(rawstring);
    list_free(elemlist);
    return false;
  }

  return true;
}


/*
 * pa_has_mask_in_policy
 *  checks that a role is masked in the given policy
 *
 */
static bool
pa_has_mask_in_policy(Oid roleid, char *policy)
{
  ObjectAddress role;
  char * seclabel = NULL;

  ObjectAddressSet(role, AuthIdRelationId, roleid);
  seclabel = GetSecurityLabel(&role, policy);

  return (seclabel && pg_strncasecmp(seclabel, "MASKED",6) == 0);
}

/*
 * pa_get_masking_policy
 *  For a given role, returns the policy in which he/she is masked or the NULL
 *  if the role is not masked.
 *
 * https://github.com/fmbiete/pgdisablelogerror/blob/main/disablelogerror.c
 */
static char *
pa_get_masking_policy(Oid roleid)
{
  ListCell   * r;
  char * policy = NULL;

  policy=pa_get_masking_policy_for_role(roleid);
  if (policy) return policy;

// Look at the parent roles
//
//  is_member_of_role(0,0);
//  foreach(r,roles_is_member_of(roleid,1,InvalidOid, NULL))
//  {
//    policy=pa_get_masking_policy_for_role(lfirst_oid(r));
//    if (policy) return policy;
//  }

  /* No masking policy found */
  return NULL;
}

static char *
pa_get_masking_policy_for_role(Oid roleid)
{
  List *      masking_policies;
  ListCell *  c;
  char *      dup = pstrdup(guc_anon_masking_policies);

  SplitGUCList(dup, ',', &masking_policies);
  foreach(c,masking_policies)
  {
    char  * policy = (char *) lfirst(c);
    if (pa_has_mask_in_policy(roleid,policy))
      return policy;
  }

  return NULL;
}


/*
 * Post-parse-analysis hook: mask query
 * https://github.com/taminomara/psql-hooks/blob/master/Detailed.md#post_parse_analyze_hook
 */
static void
#if PG_VERSION_NUM >= 140000
pa_post_parse_analyze_hook(ParseState *pstate, Query *query, JumbleState *jstate)
#else
pa_post_parse_analyze_hook(ParseState *pstate, Query *query)
#endif
{
  char * policy = NULL;

  if (prev_post_parse_analyze_hook)
    #if PG_VERSION_NUM >= 140000
    prev_post_parse_analyze_hook(pstate, query, jstate);
    #else
    prev_post_parse_analyze_hook(pstate, query);
    #endif

  if (!IsTransactionState()) return;
  if (!guc_anon_transparent_dynamic_masking) return;

  policy = pa_get_masking_policy(GetUserId());
  if (policy)
    pa_rewrite(query,policy);

  return;
}

static void
pa_rewrite(Query * query, char * policy)
{
      ereport(ERROR,
        (errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
        errmsg("NOT IMPLEMENTED YET")));
}


/*
 * pa_masking_expression_for_att
 *  returns the value for an attribute based on its masking rule (if any),
 * which can be either:
 *     - the attribute name (i.e. the authentic value)
 *     - the function or value from the masking rule
 *     - the defaut value of the column
 *     - "NULL"
 */
static char *
pa_masking_value_for_att(Relation rel, FormData_pg_attribute * att, char * policy)
{
  Oid relid;
  ObjectAddress columnobject;
  char * seclabel = NULL;
  char * attname = (char *)quote_identifier(NameStr(att->attname));

  // Get the masking rule, if any
  relid=RelationGetRelid(rel);
  ObjectAddressSubSet(columnobject, RelationRelationId, relid, att->attnum);
  seclabel = GetSecurityLabel(&columnobject, policy);

  // No masking rule found && Privacy By Default is off,
  // the authentic value is shown
  if (!seclabel && !guc_anon_privacy_by_default) return attname;

  // A masking rule was found
  if (seclabel && pg_strncasecmp(seclabel, "MASKED WITH FUNCTION", 20) == 0)
  {
    char * substr=malloc(strlen(seclabel));
    strncpy(substr, seclabel+21, strlen(seclabel));
    if (guc_anon_strict_mode) return pa_cast_as_regtype(substr, att->atttypid);
    return substr;
  }

  if (seclabel && pg_strncasecmp(seclabel, "MASKED WITH VALUE", 17) == 0)
  {
    char * substr=malloc(strlen(seclabel));
    strncpy(substr, seclabel+18, strlen(seclabel));
    if (guc_anon_strict_mode) return pa_cast_as_regtype(substr, att->atttypid);
    return substr;
  }

  // The column is declared as not masked, the authentic value is show
  if (seclabel && pg_strncasecmp(seclabel,"NOT MASKED", 10) == 0) return attname;

  // At this stage, we know privacy_by_default is on
  // Let's try to find the default value of the column
  if (att->atthasdef)
  {
    int i;
    TupleDesc reldesc;

    reldesc = RelationGetDescr(rel);
    for(i=0; i< reldesc->constr->num_defval; i++)
    {
      if (reldesc->constr->defval[i].adnum == att->attnum )
        return deparse_expression(stringToNode(reldesc->constr->defval[i].adbin),
                                  NIL, false, false);
    }

  }

  // No default value, NULL is the last possibility
  return "NULL";
}

/*
 * anon_masking_expressions_for_table
 *   returns the "select clause filters" that will mask the authentic data
 *   of a table for a given masking policy
 */
Datum
anon_masking_expressions_for_table(PG_FUNCTION_ARGS)
{
  Oid             relid = PG_GETARG_OID(0);
  char *          masking_policy = text_to_cstring(PG_GETARG_TEXT_PP(1));
  char            comma[] = " ";
  Relation        rel;
  TupleDesc       reldesc;
  StringInfoData  filters;
  int             i;

  if (PG_ARGISNULL(0) || PG_ARGISNULL(1)) PG_RETURN_NULL();

  rel = relation_open(relid, AccessShareLock);
  if (!rel) PG_RETURN_NULL();

  initStringInfo(&filters);
  reldesc = RelationGetDescr(rel);

  for (i = 0; i < reldesc->natts; i++)
  {
    FormData_pg_attribute * a;

    a = TupleDescAttr(reldesc, i);
    if (a->attisdropped) continue;

    appendStringInfoString(&filters,comma);
    appendStringInfo( &filters,
                      "%s AS %s",
                      pa_masking_value_for_att(rel,a,masking_policy),
                      (char *)quote_identifier(NameStr(a->attname))
                    );
    comma[0]=',';
  }
  relation_close(rel, NoLock);

  PG_RETURN_TEXT_P(cstring_to_text(filters.data));
}


/*
 * anon_masking_expression_for_column
 *   returns the masking filter that will mask the authentic data
 *   of a column for a given masking policy
 */
Datum
anon_masking_value_for_column(PG_FUNCTION_ARGS)
{
  Oid             relid = PG_GETARG_OID(0);
  int             colnum = PG_GETARG_INT16(1); // numbered from 1 up
  char *          masking_policy = text_to_cstring(PG_GETARG_TEXT_PP(2));
  Relation        rel;
  TupleDesc       reldesc;
  FormData_pg_attribute *a;
  StringInfoData  masking_value;

  if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2)) PG_RETURN_NULL();

  rel = relation_open(relid, AccessShareLock);
  if (!rel) PG_RETURN_NULL();

  reldesc = RelationGetDescr(rel);
  // Here attributes are numbered from 0 up
  a = TupleDescAttr(reldesc, colnum - 1);
  if (a->attisdropped) PG_RETURN_NULL();

  initStringInfo(&masking_value);
  appendStringInfoString( &masking_value,
                    pa_masking_value_for_att(rel,a,masking_policy)
                  );
  relation_close(rel, NoLock);
  PG_RETURN_TEXT_P(cstring_to_text(masking_value.data));
}

//ereport(NOTICE, (errmsg_internal("")));
