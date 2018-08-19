CREATE EXTENSION IF NOT EXISTS tsm_system_rows;
CREATE EXTENSION IF NOT EXISTS anon;

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

--
-- Personal Data (First Name, etc.)
--

-- First Name
SELECT pg_typeof(anon.random_first_name()) = 'TEXT'::REGTYPE;

-- Last Name                                                                                                                                          
SELECT pg_typeof(anon.random_last_name()) = 'TEXT'::REGTYPE;


-- Email
SELECT pg_typeof(anon.random_email()) = 'TEXT'::REGTYPE;

-- Phone
SELECT pg_typeof(anon.random_phone('0033')) = 'TEXT'::REGTYPE;
SELECT anon.random_phone(NULL) IS NULL;
SELECT pg_typeof(anon.random_phone()) = 'TEXT'::REGTYPE;

-- Location
SELECT pg_typeof(anon.random_city_in_country('France')) = 'TEXT'::REGTYPE;
SELECT anon.random_city_in_country('dfndjndjnjdnvjdnjvndjnvjdnvjdnjnvdnvjdnvj') IS NULL;
SELECT anon.random_city_in_country(NULL) IS NULL;                                                                                   
SELECT pg_typeof(anon.random_city()) = 'TEXT'::REGTYPE;                                                                                                               
SELECT pg_typeof(anon.random_region_in_country('Italy')) = 'TEXT'::REGTYPE;
SELECT anon.random_region_in_country('c,dksv,kdfsdnfvsjdnfjsdnjfndj') IS NULL;
SELECT anon.random_region_in_country(NULL) IS NULL;
SELECT pg_typeof(anon.random_region()) = 'TEXT'::REGTYPE;                                                                                 
SELECT pg_typeof(anon.random_country()) = 'TEXT'::REGTYPE; 


--
-- Company
--
SELECT pg_typeof(anon.random_company()) = 'TEXT'::REGTYPE;

--
-- IBAN
--
SELECT pg_typeof(anon.random_iban()) = 'TEXT'::REGTYPE;

--
-- SIRET
--
SELECT pg_typeof(anon.random_siret()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.random_siren()) = 'TEXT'::REGTYPE;

--
-- End
--
DROP EXTENSION anon;
