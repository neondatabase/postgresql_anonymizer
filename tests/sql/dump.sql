CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.mask_init();

CREATE TABLE customer (
	id SERIAL,
	name TEXT,
	"CreditCard" TEXT
	--fk_company INTEGER
);

INSERT INTO customer
VALUES (1,'Schwarzenegger','1234567812345678');


COMMENT ON COLUMN customer.name 
IS 'MASKED WITH FUNCTION anon.random_last_name() ';

COMMENT ON COLUMN customer."CreditCard" 
IS 'MASKED WITH FUNCTION  anon.random_string(12)';

CREATE TABLE "COMPANY" (
	rn SERIAL,
	"IBAN" TEXT,
	BRAND TEXT
);

INSERT INTO "COMPANY"
VALUES (1991,'12345677890','Cyberdyne Systems');

COMMENT ON COLUMN "COMPANY"."IBAN" IS 'MASKED WITH FUNCTION anon.random_iban()';
COMMENT ON COLUMN "COMPANY".brand IS 'MASKED WITH FUNCTION anon.random_company()';

-- 0. basic test : call the dump function
SELECT anon.dump();

-- 1. Dump into a file
\! psql -t -A -c 'SELECT anon.dump()' > dump1.sql

-- 2. Clean the database and Restore with the dump file
DROP TABLE customer CASCADE;
DROP TABLE "COMPANY" CASCADE;
\i dump1.sql

-- 3. Dump again into a second file
\! psql -t -A -c 'SELECT anon.dump()' > dump2.sql


-- 4. Check that both dump files are identical
\! diff dump1.sql dump2.sql

