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
 * An entrypoint of SECURITY LABEL statement
 */
static void
anon_object_relabel(const ObjectAddress *object, const char *seclabel)
{
  if (seclabel == NULL || strncmp(seclabel, "MASKED WITH", 11) == 0 )
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
