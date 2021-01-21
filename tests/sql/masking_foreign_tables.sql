-- This test cannot be run in a single transcation
-- This test must be run on a database named 'contrib_regression'

-- STEP 1: Creating foreign data
CREATE DATABASE foreign_data;

\c foreign_data

CREATE TABLE people ( id TEXT, firstname TEXT, lastname TEXT, phone TEXT);
INSERT INTO people VALUES ('T1','Sarah', 'Conor','0609110911');
SELECT * FROM people;

-- STEP 2: Setting FDW

\c contrib_regression

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER "external-data" FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'foreign_data'
);

CREATE USER MAPPING FOR PUBLIC SERVER "external-data" OPTIONS (
    USER 'postgres'
);

IMPORT FOREIGN SCHEMA public
FROM
    SERVER "external-data" INTO public;

\det

-- STEP 1 : Activate the masking engine
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.start_dynamic_masking();

-- STEP 2 : Declare a masked user
CREATE ROLE skynet LOGIN;
SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';

-- STEP 3 : Declare the masking rules
SECURITY LABEL FOR anon ON COLUMN people.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';

-- STEP 4 : Connect with the masked user
\! psql contrib_regression -U skynet -c "SELECT lastname != 'Conor' FROM people WHERE id = 'T1';"

-- STOP

SELECT anon.stop_dynamic_masking();

--  CLEAN

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;
DROP FOREIGN TABLE people;
