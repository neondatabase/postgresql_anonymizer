CREATE EXTENSION IF NOT EXISTS anon CASCADE;

CREATE TABLE people(name TEXT, age INT, zipcode TEXT);

-- main syntax
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH FUNCTION anon.fake_last_name()';

-- alternative syntax
COMMENT ON COLUMN people.name
IS 'MASKED WITH FUNCTION anon.fake_first_name()';

--
SECURITY LABEL FOR anon ON COLUMN people.age
IS 'MASKED WITH FUNCTION anon.random_date()';

-- main syntax
COMMENT ON COLUMN people.zipcode
IS 'MASKED WITH FUNCTION md5(NULL)';

-- only 3 rules
SELECT count(*)=3
FROM anon.pg_masking_rules;

-- the main syntax overides the alternative
SELECT count(*)=1
FROM anon.pg_masking_rules
WHERE masking_function = 'anon.fake_last_name()';

-- pg_masks works too
SELECT count(*)=0
FROM anon.pg_masks
WHERE masking_function = 'anon.fake_first_name()';

-- Clean up
DROP TABLE people CASCADE;

DROP EXTENSION anon CASCAD