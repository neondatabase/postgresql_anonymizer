CREATE EXTENSION IF NOT EXISTS anon;

-- zip
SELECT pg_typeof(anon.random_zip());


--
-- string
--

SELECT pg_typeof(anon.random_string(1));
--SELECT anon_string(123456789);

--
-- First Name
--
SELECT pg_typeof(anon.random_first_name());

--
-- Company
--
SELECT pg_typeof(anon.random_company());

--
-- Date
--
SELECT pg_typeof(anon.random_date_between('01/01/1900'::TIMESTAMP WITH TIME ZONE,now()));
SELECT pg_typeof(anon.random_date_between('01/01/0000'::DATE,'O1/O1/4000'::DATE);
SELECT pg_typeof(anon.random_date());
