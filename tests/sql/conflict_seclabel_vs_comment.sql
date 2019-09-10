CREATE EXTENSION IF NOT EXISTS anon CASCADE;

CREATE TABLE people(name TEXT);

-- main syntax
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH FUNCTION anon.fake_lastname()';

-- alternative syntax
COMMENT ON COLUMN people.name
IS 'MASKED WITH FUNCTION anon.fake_firstname()';

-- the main syntax overides the alternative
SELECT * FROM anon.pg_masking_rules;
