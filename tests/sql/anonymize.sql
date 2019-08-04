BEGIN;

CREATE TABLE stock ( id int, amount int);
INSERT INTO stock VALUES (1,1000), (2,400);

CREATE TABLE employee ( fisrtname TEXT, lastname TEXT, phone TEXT);
INSERT INTO employee VALUES ('Sarah','Connor','0609110911');
SELECT * FROM employee;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

COMMENT ON COLUMN employee.lastname IS 'MASKED WITH FUNCTION anon.fake_last_name()';
COMMENT ON COLUMN employee.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';

-- Should return a NOTICE but anonymize data anyway
SELECT anon.anonymize_column('employee','lastname');
SELECT count(*)=0 FROM employee WHERE lastname='Connor';

SELECT anon.load();

-- Anonymize all
SELECT anon.anonymize_database();

-- Anonymize a masked table
SELECT anon.anonymize_table('employee');

-- Anonymize a table with no mask
-- returns NULL
SELECT anon.anonymize_table('stock') IS NULL;

-- Anonymize a table that does not exist
SELECT anon.anonymize_table('employee');

-- Anonymize a masked column
SELECT anon.anonymize_column('employee','phone');

-- Anonymize an unmasked column
-- returns FALSE and a WARNING
SELECT anon.anonymize_column('employee','firstname') IS FALSE;

-- Anonymize a column that does not exist
-- returns FALSE and a WARNING
SELECT anon.anonymize_column('employee','xxxxxxxxxxxxxxxx') IS FALSE;


ROLLBACK;
