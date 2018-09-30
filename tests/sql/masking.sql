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
	id_company SERIAL,
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

SELECT company != 'Cyberdyne Systems' FROM mask."T2" WHERE id_company=1991;

SELECT name != 'Schwarzenegger' FROM mask.t1 WHERE id = 1;

-- ROLE

CREATE ROLE skynet;
COMMENT ON ROLE skynet IS 'MASKED';

SELECT anon.hasmask('skynet');

SELECT anon.hasmask('postgres') IS FALSE;

SELECT anon.hasmask(NULL) IS NULL; 

-- STATIC SUBST

SELECT anon.static_substitution();

SELECT company != 'Cyberdyne Systems' FROM "T2" WHERE id_company=1991;

SELECT name != 'Schwarzenegger' FROM t1 WHERE id = 1; 

--  CLEAN

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;

