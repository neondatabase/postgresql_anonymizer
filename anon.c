/*
 * This comes directly from the dummy_seclabel example
 * see https://github.com/postgres/postgres/blob/master/src/test/modules/dummy_seclabel/dummy_seclabel.c
 *
 */

#include "postgres.h"
#include "commands/seclabel.h"
#include "fmgr.h"


PG_MODULE_MAGIC;

/*
 * Declarations
 */
void    _PG_init(void);

PG_FUNCTION_INFO_V1(anon_seclabel_anon);

/*
 * Checking the syntax of the masking rules
 */
static void
anon_object_relabel(const ObjectAddress *object, const char *seclabel)
{
  if (seclabel == NULL
    || pg_strcasecmp(seclabel,"MASKED") == 0
    || pg_strncasecmp(seclabel, "MASKED WITH FUNCTION", 20) == 0
    || pg_strncasecmp(seclabel, "MASKED WITH VALUE", 17) == 0
    || pg_strncasecmp(seclabel, "QUASI IDENTIFIER",17) == 0
    || pg_strncasecmp(seclabel, "INDIRECT IDENTIFIER",19) == 0
  )
  return;

  ereport(ERROR,
      (errcode(ERRCODE_INVALID_NAME),
       errmsg("'%s' is not a valid masking rule", seclabel)));
}


void
_PG_init(void)
{
  /* Security label provider hook */
  register_label_provider("anon",anon_object_relabel);
}

/*
 * This function is here just so that the extension is not completely empty
 * and the dynamic library is loaded when CREATE EXTENSION runs.
 */
Datum
anon_seclabel_anon(PG_FUNCTION_ARGS)
{
  PG_RETURN_VOID();
}
