-- This test cannot be run in a single transcation
-- This test must be run on a database named 'contrib_regression'

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.mask_init();

SELECT anon.mask_init('public','foo');

SELECT anon.start_dynamic_masking();

SELECT anon.start_dynamic_masking('public','foo');

CREATE TABLE t1 (
  id SERIAL,
  name TEXT,
  "CreditCard" TEXT
--  fk_company INTEGER
);

INSERT INTO t1
VALUES (1,'Schwarzenegger','1234567812345678');

-- Check old syntax
COMMENT ON COLUMN t1.name
IS '    MASKED WITH FUNCTION anon.random_last_name() ';

COMMENT ON COLUMN t1."CreditCard"
IS 'dfkjdsiv MASKED    WITH    FUNCTION         anon.random_string(12)';

CREATE TABLE "T2" (
  rn SERIAL,
  "IBAN" TEXT,
  COMPANY TEXT
);

INSERT INTO "T2"
VALUES (1991,'12345677890','Cyberdyne Systems');

-- New syntax
SECURITY LABEL FOR anon
ON COLUMN  "T2"."IBAN"
IS 'MASKED WITH FUNCTION anon.random_iban()';

SECURITY LABEL FOR anon
ON COLUMN "T2".COMPANY
IS 'MASKED WITH FUNCTION anon.random_company() jenfk snvi  jdvjs';


SELECT count(*) = 4  FROM anon.pg_masking_rules;

SELECT masking_function = 'anon.random_iban()'
FROM anon.pg_masking_rules
WHERE attname = 'IBAN';

--

SELECT company != 'Cyberdyne Systems' FROM foo."T2" WHERE rn=1991;

SELECT name != 'Schwarzenegger' FROM foo.t1 WHERE id = 1;

-- ROLE

CREATE ROLE skynet LOGIN;

SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';

SELECT anon.mask_update();

CREATE ROLE hal LOGIN;

COMMENT ON ROLE hal IS 'MASKED';

SELECT anon.mask_update();

-- search_path must be 'foo,public'
\! psql contrib_regression -U skynet -c 'SHOW search_path;'

-- search_path must be 'foo,public'
\! psql contrib_regression -U hal -c 'SHOW search_path;'

-- Disabling this test, because the error message has changed between PG10 and PG11
-- This test should fail anyway, the skynet role is not allowed to access the t1 table
--\! psql contrib_regression -U skynet -c "SELECT * FROM public.t1;"

\! psql contrib_regression -U skynet -c "SELECT name != 'Schwarzenegger' FROM t1 WHERE id = 1;"

\! psql contrib_regression -U skynet -c "SELECT company != 'Cyberdyne Systems' FROM \"T2\" WHERE rn=1991;"

-- STOP

SELECT anon.stop_dynamic_masking();

--  CLEAN

DROP TABLE "T2" CASCADE;
DROP TABLE t1 CASCADE;

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;

REASSIGN OWNED BY hal TO postgres;
DROP OWNED BY hal CASCADE;
DROP ROLE hal;

