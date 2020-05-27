BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

--
-- Generic Types
--

-- zip
SELECT pg_typeof(anon.random_zip()) = 'TEXT'::REGTYPE;


-- string

SELECT pg_typeof(anon.random_string(1)) = 'TEXT'::REGTYPE;


-- Date
SELECT pg_typeof(anon.random_date_between('1900-01-01'::TIMESTAMP WITH TIME ZONE,now())) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;
SELECT pg_typeof(anon.random_date_between('0001-01-01'::DATE,'4001-01-01'::DATE)) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;
SELECT pg_typeof(anon.random_date()) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;

-- Integer
SELECT pg_typeof(anon.random_int_between(1,3)) = 'INTEGER'::REGTYPE;
SELECT ROUND(AVG(anon.random_int_between(1,3))) = 2
FROM generate_series(1,100);

SELECT pg_typeof(anon.random_bigint_between(1,3)) = 'BIGINT'::REGTYPE;
SELECT ROUND(AVG(anon.random_bigint_between(2147483648,2147483650))) = 2147483649
FROM generate_series(1,100);


-- Phone
SELECT pg_typeof(anon.random_phone('0033')) = 'TEXT'::REGTYPE;
SELECT anon.random_phone(NULL) IS NULL;
SELECT pg_typeof(anon.random_phone()) = 'TEXT'::REGTYPE;

-- Array
SELECT anon.random_in(NULL::DATE[]) IS NULL;
SELECT avg(anon.random_in(ARRAY[1,2,3]))::INT = 2 FROM generate_series(1,100);
SELECT pg_typeof(anon.random_in(ARRAY['yes','no','maybe'])) = 'TEXT'::REGTYPE;


DROP EXTENSION anon CASCADE;

ROLLBACK;
