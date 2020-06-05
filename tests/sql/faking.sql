CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.init();

--
-- Personal Data (First Name, etc.)
--

-- First Name
SELECT pg_typeof(anon.random_first_name()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_first_name()) = 'TEXT'::REGTYPE;

-- Last Name
SELECT pg_typeof(anon.random_last_name()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_last_name()) = 'TEXT'::REGTYPE;

-- Email
SELECT pg_typeof(anon.random_email()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_email()) = 'TEXT'::REGTYPE;


-- Location
SELECT pg_typeof(anon.random_city_in_country('France')) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_city_in_country('France')) = 'TEXT'::REGTYPE;

SELECT anon.random_city_in_country('dfndjndjnjdnvjdnjvndjnvjdnvjdnjnvdnvjdnvj') IS NULL;
SELECT anon.fake_city_in_country('dfndjndjnjdnvjdnjvndjnvjdnvjdnjnvdnvjdnvj') IS NULL;

SELECT anon.random_city_in_country(NULL) IS NULL;
SELECT anon.fake_city_in_country(NULL) IS NULL;

SELECT pg_typeof(anon.random_city()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_city()) = 'TEXT'::REGTYPE;

SELECT pg_typeof(anon.random_region_in_country('Italy')) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_region_in_country('Italy')) = 'TEXT'::REGTYPE;

SELECT anon.random_region_in_country('c,dksv,kdfsdnfvsjdnfjsdnjfndj') IS NULL;
SELECT anon.fake_region_in_country('c,dksv,kdfsdnfvsjdnfjsdnjfndj') IS NULL;

SELECT anon.random_region_in_country(NULL) IS NULL;
SELECT anon.fake_region_in_country(NULL) IS NULL;

SELECT pg_typeof(anon.random_region()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_region()) = 'TEXT'::REGTYPE;

SELECT pg_typeof(anon.random_country()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_country()) = 'TEXT'::REGTYPE;


--
-- Company
--
SELECT pg_typeof(anon.random_company()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_company()) = 'TEXT'::REGTYPE;

--
-- IBAN
--
SELECT pg_typeof(anon.random_iban()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_iban()) = 'TEXT'::REGTYPE;

--
-- SIRET
--
SELECT pg_typeof(anon.fake_siret()) = 'TEXT'::REGTYPE;
SELECT pg_typeof(anon.fake_siren()) = 'TEXT'::REGTYPE;

--
-- Lorem Ipsum
--
SELECT COUNT(*) = 5-1
FROM (
  SELECT regexp_matches(anon.lorem_ipsum(), E'\n', 'g')
) AS l;

SELECT COUNT(*) = 19-1
FROM (
  SELECT regexp_matches(anon.lorem_ipsum(19), E'\n', 'g')
) AS l;

SELECT COUNT(*) = 7-1
FROM (
  SELECT regexp_matches(anon.lorem_ipsum( paragraphs := 7 ), E'\n', 'g')
) AS l;

SELECT COUNT(*) = 20
FROM unnest(string_to_array( anon.lorem_ipsum( words := 20 ), ' ') )
AS l;

SELECT char_length(anon.lorem_ipsum( characters := 7 )) = 7;

SELECT char_length(anon.lorem_ipsum( characters := 7 , words := 100)) = 7;

SELECT char_length(anon.lorem_ipsum( characters := 7 , paragraphs := 100)) = 7;

DROP EXTENSION anon CASCADE;
