BEGIN;

CREATE TABLE employee ( fisrtname TEXT, lastname TEXT, phone TEXT);
INSERT INTO employee VALUES ('Sarah','Connor','0609110911');
SELECT * FROM employee;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

COMMENT ON COLUMN employee.lastname IS 'MASKED WITH FUNCTION anon.random_last_name()';
COMMENT ON COLUMN employee.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';

-- Should return a NOTICE but anonymize data anyway
SELECT anon.anonymize();

SELECT count(*)=0 FROM employee WHERE lastname='Connor';

SELECT anon.load();

-- No NOTICE this time
SELECT anon.anonymize();

ROLLBACK;
