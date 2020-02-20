BEGIN;

CREATE SCHEMA dbo;

CREATE TABLE dbo.tbl1(
    staff_id SERIAL PRIMARY KEY,
    firstname VARCHAR(45) NOT NULL,
    lastname VARCHAR(45) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);
SECURITY LABEL FOR anon ON COLUMN dbo.tbl1.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

SELECT * FROM dbo.tbl1;

SELECT anon.start_dynamic_masking('dbo');

SELECT * FROM dbo.tbl1;

ROLLBACK;


