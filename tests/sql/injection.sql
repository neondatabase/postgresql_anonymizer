-- This test cannot be run in a single transaction
-- because it will produce expected errors

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Sample Table
CREATE TABLE a (
    i SERIAL,
    d TIMESTAMP,
    x INTEGER
);



--
-- random_phone
--

--returns TRUE
SELECT anon.random_phone('11; SELECT 0;') LIKE '11; SELECT 0;%';

--
-- add_noise_on_numeric_column
--

-- returns 'invalid name syntax'
SELECT anon.add_noise_on_numeric_column('a; SELECT 1','x',0.5);
-- returns a WARNING and FALSE
SELECT anon.add_noise_on_numeric_column('a','x; SELECT 1',0.5) IS FALSE;

--
-- add_noise_on_datetime_column
--

-- returns 'invalid name syntax'
SELECT anon.add_noise_on_datetime_column('a; SELECT 1','d','2 days');
-- returns a WARNING and FALSE
SELECT anon.add_noise_on_datetime_column('a','d; SELECT 1','2 days') IS FALSE;
-- returns 'invalid name syntax'
SELECT anon.add_noise_on_datetime_column('a','d','2 days; SELECT 1');

--
-- shuffle_column
--

-- returns 'invalid name syntax'
SELECT anon.shuffle_column('a; SELECT 1','x','i');
-- returns a WARNING and FALSE
SELECT anon.shuffle_column('a','x; SELECT 1','i') IS FALSE;
-- returns a WARNING and FALSE
SELECT anon.shuffle_column('a','x','i; SELECT 1') IS FALSE;

--
-- load
--

-- returns a WARNING and FALSE
SELECT anon.load('base/''; CREATE TABLE inject_via_load (i int);--') IS FALSE;

SELECT COUNT(*) = 0
FROM pg_tables
WHERE tablename='inject_via_load';

--
-- Dynamic Masking
--

-- returns TRUE
SELECT anon.start_dynamic_masking(
  'public',
  'foo; CREATE TABLE inject_via_init (i int);--'
);

SELECT COUNT(*) = 0
FROM pg_tables
WHERE tablename='inject_via_init';

--
-- Masking Rule Syntax
--

SECURITY LABEL FOR anon ON COLUMN a.x
IS 'MASKED WITH VALUE foo; CREATE TABLE inject_via_rule (i int);--';

SELECT COUNT(*) = 0
FROM pg_tables
WHERE tablename='inject_via_rule';

-- CLEAN UP
DROP TABLE a CASCADE;
DROP EXTENSION anon CASCADE;

