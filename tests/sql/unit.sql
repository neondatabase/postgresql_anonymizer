CREATE EXTENSION IF NOT EXISTS anon;

--                                                                                                                                                     
-- Generic Types                                                                                                                                       
--     

-- zip
SELECT pg_typeof(anon.random_zip());


-- string

SELECT pg_typeof(anon.random_string(1));
--SELECT anon_string(123456789);


-- Date                                                                                                                                                
SELECT pg_typeof(anon.random_date_between('01/01/1900'::TIMESTAMP WITH TIME ZONE,now()));                                                              
SELECT pg_typeof(anon.random_date_between('01/01/0001'::DATE,'01/01/4001'::DATE));                                                                     
SELECT pg_typeof(anon.random_date());  

-- Integer
SELECT pg_typeof(anon.random_int_between(1,3));

--
-- Personal Data (First Name, etc.)
--

-- First Name
SELECT pg_typeof(anon.random_first_name());

-- Last Name                                                                                                                                          
SELECT pg_typeof(anon.random_last_name());

-- Phone
SELECT pg_typeof(anon.random_phone('0033'));
SELECT pg_typeof(anon.random_phone());

--
-- Company
--

SELECT pg_typeof(anon.random_company());

--
-- Date
--
SELECT pg_typeof(anon.random_date_between('01/01/1900'::TIMESTAMP WITH TIME ZONE,now()));
SELECT pg_typeof(anon.random_date_between('01/01/0001'::DATE,'01/01/4001'::DATE));
SELECT pg_typeof(anon.random_date());
