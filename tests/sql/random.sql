CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

--
-- Generic Types
--

-- zip
SELECT pg_typeof(anon.random_zip()) = 'TEXT'::REGTYPE;


-- string

SELECT pg_typeof(anon.random_string(1)) = 'TEXT'::REGTYPE;
--SELECT anon_string(123456789);


-- Date
SELECT pg_typeof(anon.random_date_between('01/01/1900'::TIMESTAMP WITH TIME ZONE,now())) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;
SELECT pg_typeof(anon.random_date_between('01/01/0001'::DATE,'01/01/4001'::DATE)) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;
SELECT pg_typeof(anon.random_date()) = 'TIMESTAMP WITH TIME ZONE'::REGTYPE;

-- Integer
SELECT pg_typeof(anon.random_int_between(1,3)) = 'INTEGER'::REGTYPE;


-- Phone
SELECT pg_typeof(anon.random_phone('0033')) = 'TEXT'::REGTYPE;
SELECT anon.random_phone(NULL) IS NULL;
SELECT pg_typeof(anon.random_phone()) = 'TEXT'::REGTYPE;

DROP EXTENSION anon CASCADE;
