CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.mask_init();

CREATE TABLE t1 (
	id SERIAL,
	name TEXT,
	"CreditCard" TEXT,
	fk_company INTEGER
);

INSERT INTO t1
VALUES (1,'Schwarzenegger','1234567812345678', 1991);


COMMENT ON COLUMN t1.name IS '  MASKED WITH FUNCTION anon.random_last_name() ';
COMMENT ON COLUMN t1."CreditCard" IS '  MASKED    WITH    FUNCTION         anon.random_string(12)';

CREATE TABLE "T2" (
	rn SERIAL,
	"IBAN" TEXT,
	COMPANY TEXT
);

INSERT INTO "T2"
VALUES (1991,'12345677890','Cyberdyne Systems');

COMMENT ON COLUMN "T2"."IBAN" IS 'MASKED WITH FUNCTION anon.random_iban()';
COMMENT ON COLUMN "T2".COMPANY IS 'jvnosdfnvsjdnvfskngvknfvg MASKED WITH FUNCTION anon.random_company() jenfk snvi  jdnvkjsnvsndvjs';


SELECT count(*) = 4  FROM anon.pg_masks;

SELECT masking_function = 'anon.random_iban()' FROM anon.pg_masks WHERE attname = 'IBAN';

--

SELECT company != 'Cyberdyne Systems' FROM mask."T2" WHERE rn=1991;

SELECT name != 'Schwarzenegger' FROM mask.t1 WHERE id = 1;

-- ROLE

CREATE ROLE skynet LOGIN;
COMMENT ON ROLE skynet IS 'MASKED';

-- FORCE update because COMMENT doesn't trigger the Event Trigger
SELECT anon.mask_update();

SELECT anon.hasmask('skynet');

SELECT anon.hasmask('postgres') IS FALSE;

SELECT anon.hasmask(NULL) IS NULL;

\! psql contrib_regression -U skynet -c 'SHOW search_path;'

-- Disabling this test, because the error message has changed between PG10 and PG11
-- This test should fail anyway, the skynet role is not allowed to access the t1 table
--\! psql contrib_regression -U skynet -c "SELECT * FROM public.t1;"

\! psql contrib_regression -U skynet -c "SELECT name != 'Schwarzenegger' FROM t1 WHERE id = 1;"

\! psql contrib_regression -U skynet -c "SELECT company != 'Cyberdyne Systems' FROM \"T2\" WHERE rn=1991;"

-- STATIC SUBST

SELECT anon.static_substitution();

SELECT company != 'Cyberdyne Systems' FROM "T2" WHERE rn=1991;

SELECT name != 'Schwarzenegger' FROM t1 WHERE id = 1;

--  CLEAN

DROP TABLE "T2" CASCADE;
DROP TABLE t1 CASCADE;

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;
