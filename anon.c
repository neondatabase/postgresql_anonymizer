/*
 * This comes directly from the dummy_seclabel example
 * see https://github.com/postgres/postgres/blob/master/src/test/modules/dummy_seclabel/dummy_seclabel.c
 *
 */

#include "postgres.h"
#include "commands/seclabel.h"
#include "parser/parser.h"
#include "utils/builtins.h"
#include "fmgr.h"
#include "utils/guc.h"
#include "catalog/pg_class.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_authid.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

/*
 * Declarations
 */
#ifdef _WIN64
PGDLLEXPORT void    _PG_init(void);
PGDLLEXPORT Datum   get_function_schema(PG_FUNCTION_ARGS);
PGDLLEXPORT void    register_label(PG_FUNCTION_ARGS);
#else
void    _PG_init(void);
Datum   get_function_schema(PG_FUNCTION_ARGS);
Datum   register_label(PG_FUNCTION_ARGS);
#endif


PG_FUNCTION_INFO_V1(get_function_schema);
PG_FUNCTION_INFO_V1(register_label);

static bool guc_anon_restrict_to_trusted_schemas;
// Some GUC vars below are not used in the C code
// but they are used in the plpgsql code
// compile with `-Wno-unused-variable` to avoid warnings
static char *guc_anon_algorithm;
static char *guc_anon_masking_policies;
static char *guc_anon_mask_schema;
static bool guc_anon_privacy_by_default;
static char *guc_anon_salt;
static char *guc_anon_source_schema;


/*
 * Checking the syntax of the masking rules
 */
static void
anon_object_relabel(const ObjectAddress *object, const char *seclabel)
{
  /* SECURITY LABEL FOR anon ON COLUMN foo.bar IS NULL */
  if (seclabel == NULL) return;

 // ereport(ERROR,
 //       (errcode(ERRCODE_INVALID_NAME),
 //       errmsg("classId = %d + SubId = %d", object->classId, object->objectSubId)));

  switch (object->classId)
  {
    case RelationRelationId:

      /* SECURITY LABEL FOR anon ON TABLE ...' */
      if (object->objectSubId == 0)
        ereport(ERROR,
          (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
           errmsg("anon provider does not support labels on this object")));

      /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
      if ( pg_strncasecmp(seclabel, "MASKED WITH FUNCTION", 20) == 0
        || pg_strncasecmp(seclabel, "MASKED WITH VALUE", 17) == 0
        || pg_strncasecmp(seclabel, "QUASI IDENTIFIER",17) == 0
        || pg_strncasecmp(seclabel, "INDIRECT IDENTIFIER",19) == 0
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
 * get_function_schema
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
get_function_schema(PG_FUNCTION_ARGS)
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
