CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.mask_init();

-- Table `people` 
CREATE TABLE people (
	id SERIAL UNIQUE,
	name TEXT,
	"CreditCard" TEXT,
	fk_company INTEGER
);

INSERT INTO people
VALUES (1,'Schwarzenegger','1234567812345678', 1991);


COMMENT ON COLUMN people.name IS '  MASKED WITH FUNCTION anon.random_last_name() ';
COMMENT ON COLUMN people."CreditCard" IS '  MASKED    WITH    FUNCTION         anon.random_string(12)';

-- Table `CoMPaNy` 
CREATE TABLE "CoMPaNy" (
	id_company SERIAL UNIQUE,
	"IBAN" TEXT,
	NAME TEXT
);

INSERT INTO "CoMPaNy"
VALUES (1991,'12345677890','Cyberdyne Systems');

COMMENT ON COLUMN "CoMPaNy"."IBAN" IS 'MASKED WITH FUNCTION anon.random_iban()';
COMMENT ON COLUMN "CoMPaNy".NAME IS 'jvnosdfnvsjdnvfskngvknfvg MASKED WITH FUNCTION anon.random_company() jenfk snvi  jdnvkjsnvsndvjs';

-- Table `work` 
CREATE TABLE work (
	id_work SERIAL,
	fk_employee INTEGER NOT NULL,
	fk_company INTEGER NOT NULL,
	first_day DATE NOT NULL,
	last_day DATE,
	FOREIGN KEY	(fk_employee) references people(id),
	FOREIGN KEY (fk_company) references "CoMPaNy"(id_company)
);

INSERT INTO work
VALUES ( 1, 1 , 1991, DATE '1985/05/25',NULL);

SELECT count(*) = 4  FROM anon.pg_masks;

SELECT masking_function = 'anon.random_iban()' FROM anon.pg_masks WHERE attname = 'IBAN';

--

SELECT name != 'Cyberdyne Systems' FROM mask."CoMPaNy" WHERE id_company=1991;

SELECT name != 'Schwarzenegger' FROM mask.people WHERE id = 1;

-- ROLE

CREATE ROLE skynet LOGIN;
COMMENT ON ROLE skynet IS 'MASKED';

-- FORCE update because COMMENT doesn't trigger the Event Trigger
SELECT anon.mask_update();

SELECT anon.hasmask('skynet');

SELECT anon.hasmask('postgres') IS FALSE;

SELECT anon.hasmask(NULL) IS NULL;

-- We're using an external connection instead of `SET ROLE`
-- Because we need the tricky search_path
\! psql contrib_regression -U skynet -c 'SHOW search_path;'

-- Disabling this test, because the error message has changed between PG10 and PG11
-- This test should fail anyway, the skynet role is not allowed to access the people table
--\! psql contrib_regression -U skynet -c "SELECT * FROM public.people;"

\! psql contrib_regression -U skynet -c "SELECT name != 'Schwarzenegger' FROM people WHERE id = 1;"

\! psql contrib_regression -U skynet -c "SELECT name != 'Cyberdyne Systems' FROM \"CoMPaNy\" WHERE id_company=1991;"

-- STATIC SUBST

SELECT anon.static_substitution();

SELECT name != 'Cyberdyne Systems' FROM "CoMPaNy" WHERE id_company=1991;

SELECT name != 'Schwarzenegger' FROM people WHERE id = 1;


-- A maked role cannot modify a table containing a mask column

\! psql contrib_regression -U skynet -c "DELETE FROM people;"

\! psql contrib_regression -U skynet -c "UPDATE people SET name = 'check' WHERE name ='Schwarzenegger';"

\! psql contrib_regression -U skynet -c "INSERT INTO people VALUES (1,'Schwarzenegger','1234567812345678', 1991);" ;

\! psql contrib_regression -U skynet -c "DELETE FROM work;";

--  CLEAN

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;

