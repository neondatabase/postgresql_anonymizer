-- this test must be run on a database named 'contrib_regression'
CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.load();

CREATE SCHEMA test_pg_dump_anon;

CREATE TABLE test_pg_dump_anon.no_masks AS SELECT 1 ;

CREATE TABLE test_pg_dump_anon.cards (
  id integer NOT NULL,
  board_id integer NOT NULL,
  data TEXT
);

INSERT INTO test_pg_dump_anon.cards VALUES
(1, 1, 'Paint house'),
(2, 1, 'Clean'),
(3, 1, 'Cook'),
(4, 1, 'Vacuum'),
(999999,0, E'(,Very"Weird\'\'value\t trying\n to\,break '' CSV\)export)');

CREATE TABLE test_pg_dump_anon.customer (
  id SERIAL,
  name TEXT,
  "CreditCard" TEXT
);

INSERT INTO test_pg_dump_anon.customer
VALUES (1,'Schwarzenegger','1234567812345678');

SECURITY LABEL FOR anon ON COLUMN test_pg_dump_anon.customer.name
IS E'MASKED WITH FUNCTION md5(''0'') ';

SECURITY LABEL FOR anon ON COLUMN test_pg_dump_anon.customer."CreditCard"
IS E'MASKED WITH FUNCTION md5(''0'') ';

CREATE TABLE test_pg_dump_anon."COMPANY" (
  rn SERIAL,
  "IBAN" TEXT,
  BRAND TEXT
);

INSERT INTO test_pg_dump_anon."COMPANY"
VALUES (1991,'12345677890','Cyberdyne Systems');

SECURITY LABEL FOR anon ON COLUMN test_pg_dump_anon."COMPANY"."IBAN"
IS E'MASKED WITH FUNCTION md5(''0'') ';

SECURITY LABEL FOR anon ON COLUMN test_pg_dump_anon."COMPANY".brand
IS E'MASKED WITH FUNCTION md5(''0'')';

-- 1. Dump into a file
\! pg_dump_anon contrib_regression > tests/tmp/_pg_dump_anon_1.sql

-- 2. Clean up the database
DROP SCHEMA test_pg_dump_anon CASCADE;
DROP EXTENSION anon CASCADE;

-- 3. Restore with the dump file
-- output will vary a lot between PG versions
-- So have to disable it to pass this test
\! psql -f tests/tmp/_pg_dump_anon_1.sql contrib_regression >/dev/null

-- 3. Dump again into a second file
-- /!\ This time the masking rules are not applied !
\! pg_dump_anon -d contrib_regression > tests/tmp/_pg_dump_anon_2.sql


-- 4. Check that both dump files are identical
\! diff tests/tmp/_pg_dump_anon_1.sql tests/tmp/_pg_dump_anon_2.sql

--  CLEAN
DROP SCHEMA test_pg_dump_anon CASCADE;

DROP EXTENSION anon CASCADE;
