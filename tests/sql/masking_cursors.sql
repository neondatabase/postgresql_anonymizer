-- This test can't be runned inside a single transaction
-- because the FECTH statements need to be in their own transaction

CREATE EXTENSION anon;

SET anon.transparent_dynamic_masking TO TRUE;

CREATE TABLE t AS SELECT n FROM generate_series(1,100) n;

SECURITY LABEL FOR anon ON COLUMN t.n
  IS 'masked with VALUE 0';

CREATE ROLE dumper LOGIN;

security label for anon on role dumper
  is 'masked';

GRANT SELECT ON TABLE t TO dumper;

SET ROLE dumper;

-- need to be in a transaction to use cursors.
BEGIN;

  DECLARE max_n SCROLL CURSOR FOR SELECT max(n) FROM t;
  FETCH max_n;

ROLLBACK;

RESET ROLE;

DROP TABLE t;

REASSIGN OWNED BY dumper TO postgres;
DROP OWNED BY dumper;
DROP ROLE dumper;

DROP EXTENSION anon;
