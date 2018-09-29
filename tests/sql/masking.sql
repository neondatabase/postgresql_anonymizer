CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.mask_init();

CREATE TEMPORARY TABLE t1 (
	id SERIAL,
	name TEXT,
	"CreditCard" TEXT,
	fk_company INTEGER
);

INSERT INTO t1 
VALUES (1,'Schwarzenegger','1234567812345678', 1991);


COMMENT ON COLUMN t1.name IS '  MASKED WITH random_last_name() )';
COMMENT ON COLUMN t1."CreditCard" IS '  MASKED WITH random_string(12) )';

CREATE TEMPORARY TABLE "T2" (
	id_company SERIAL,
	"IBAN" TEXT,
	COMPANY TEXT
);

INSERT INTO "T2"
VALUES (1991,'12345677890','Skynet');

COMMENT ON COLUMN "T2"."IBAN" IS 'MASKED WITH random_iban))';
COMMENT ON COLUMN "T2".COMPANY IS 'jvnosdfnvsjdnvfskngvknfvg MASKED WITH random_company() jenfksnvjdnvkjsnvsndvjs';


SELECT count(*) = 4  FROM anon.pg_masks;

SELECT func = 'random_iban()' FROM anon.pg_masks WHERE attname = 'IBAN';


-- FIXME

-- SELECT anon.static_substitution();

SELECT company != 'skynet' FROM "T2" WHERE id_company=1991;

SELECT name != 'Schwarzenegger' FROM t1 WHERE id = 1; 



DROP EXTENSION anon CASCADE;
