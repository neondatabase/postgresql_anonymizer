
--
-- Wait for PGRX 0.12 rc to remove this function
--

-- Walk through all tables with masked columns and execute anonymize_table on them
CREATE OR REPLACE FUNCTION anon.anonymize_database()
RETURNS BOOLEAN AS
$$
  SELECT bool_or(anon.anonymize_table(t.regclass))
  FROM (
      SELECT distinct attrelid::REGCLASS as regclass
      FROM anon.pg_masking_rules
  ) as t;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.anonymize_database IS 'UNTRUSTED';
