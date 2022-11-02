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

#include "commands/seclabel.h"
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
#include "miscadmin.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/ruleutils.h"

PG_MODULE_MAGIC;

/*
 * External Functions
 */
PGDLLEXPORT Datum   anon_get_function_schema(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum   anon_masking_expressions_for_table(PG_FUNCTION_ARGS);
PGDLLEXPORT Datum   anon_masking_value_for_column(PG_FUNCTION_ARGS);

#ifdef _WIN64
PGDLLEXPORT void    _PG_init(void);
PGDLLEXPORT Datum   register_label(PG_FUNCTION_ARGS);
#else
void    _PG_init(void);
Datum   register_label(PG_FUNCTION_ARGS);
#endif

PG_FUNCTION_INFO_V1(anon_get_function_schema);
PG_FUNCTION_INFO_V1(anon_masking_expressions_for_table);
PG_FUNCTION_INFO_V1(anon_masking_value_for_column);
PG_FUNCTION_INFO_V1(register_label);

/*
 * Internal functions
 */
static char * pa_cast_as_regtype(char * value, int atttypid);
static char * pa_masking_value_for_att(Relation rel, FormData_pg_attribute * att, char * policy);

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


/*
 * Checking the syntax of the masking rules
 */
static void
anon_object_relabel(const ObjectAddress *object, const char *seclabel)
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
           errmsg("anon provider does not support labels on this object")));
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
anon_k_anonymity_object_relabel(const ObjectAddress *object, const char *seclabel)
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
 * Trim whitespaces from a string
 */
static void
remove_spaces(char *s)
{
    int writer = 0, reader = 0;
    while (s[reader])
    {
        if (s[reader]!=' ') s[writer++] = s[reader];
        reader++;
    }
    s[writer]=0;
}

/*
 * Register the extension and declare its GUC variables
 */
void
_PG_init(void)
{
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
    "",
    PGC_SIGHUP,
    GUC_SUPERUSER_ONLY,
    NULL,
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
    0,
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

  // Provider for k-anonimity
  register_label_provider(guc_anon_k_anonymity_provider,
                          anon_k_anonymity_object_relabel
  );

  /* Security label provider hook */
  /* 'anon' is always used as the default policy */
  register_label_provider("anon",anon_object_relabel);
  /* Additional providers for multiple masking policies */
  if (strlen(guc_anon_masking_policies)>0)
  {
    char * policy = strtok(guc_anon_masking_policies, ",");
    while( policy != NULL )
    {
      remove_spaces(policy);
      register_label_provider(policy,anon_object_relabel);
      policy = strtok(NULL, ",");
    }
  }
}

/*
 * pa_cast_as_regtype
 * decorates a value with a CAST function
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

Datum
register_label(PG_FUNCTION_ARGS)
{
    bool input_is_null = PG_ARGISNULL(0);
    char* policy= text_to_cstring(PG_GETARG_TEXT_PP(0));

    if (input_is_null) PG_RETURN_NULL();
    register_label_provider(policy,anon_object_relabel);
    return true;
}


/*
 * masking_expression_for_att
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
 * pa_anon_masking_expression_for_column
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

/*
 * pa_anon_masking_expressions_for_table
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

//ereport(NOTICE, (errmsg_internal("")));
