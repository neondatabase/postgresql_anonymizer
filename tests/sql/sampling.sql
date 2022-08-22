BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

CREATE TABLE hundred AS
SELECT generate_series(1,100) AS h;

SECURITY LABEL FOR anon ON TABLE hundred
IS 'TABLESAMPLE BERNOULLI (33)';

SECURITY LABEL FOR anon ON COLUMN hundred.h
IS 'MASKED WITH VALUE 0';

SELECT anon.mask_sample('hundred'::REGCLASS);



SELECT count(*) = 100 FROM hundred;

SELECT anon.anonymize_database();

SELECT count(*) != 100 FROM hundred;

--ROLLBACK;
