
--BEGIN;

--
-- First names
-- A bit of cleaning is required
--

DROP TABLE IF EXISTS first_name_raw;
CREATE TEMPORARY TABLE first_name_raw (
  first_name TEXT,
  gender TEXT,
  language TEXT,
  frequency FLOAT
);

\copy first_name_raw FROM 'data/first_names.csv' with ( FORMAT CSV, HEADER true, DELIMITER ';', ENCODING 'latin-9' );

DROP TABLE if EXISTS first_name;
CREATE TABLE first_name AS
SELECT
  first_name,
  (CASE WHEN gender ~ 'm' THEN 1 ELSE 0 END)::boolean AS male,
  (CASE WHEN gender ~ 'f' THEN 1 ELSE 0 END)::boolean AS female,
  language
FROM first_name_raw;

--
-- Last names
-- Raw data is ok
--

DROP TABLE IF EXISTS last_name;
CREATE TABLE last_name (
    name TEXT
);

\copy last_name FROM 'data/last_names.csv' WITH (FORMAT CSV, HEADER true);

--
-- Email
--
DROP TABLE IF EXISTS email;
CREATE TABLE email (
  address TEXT
);

\copy email FROM 'data/email.csv' WITH ( FORMAT CSV, HEADER true );

--
-- Cities, Regions & Countries
--
DROP TABLE IF EXISTS city;
CREATE TABLE city (
  name TEXT,
  country TEXT,
  subcountry TEXT,
  geonameid TEXT
);

\copy city FROM 'data/world-cities_csv.csv' WITH ( FORMAT CSV, HEADER true, DELIMITER ',');

--
-- Companies
-- No cleaning required
--


DROP TABLE IF EXISTS company;
CREATE TABLE company (
  name TEXT
);

\copy company FROM 'data/companies.csv';


DROP TABLE IF EXISTS iban;
CREATE TABLE iban (
  id TEXT
);

\copy iban FROM 'data/iban.csv' ( FORMAT CSV, HEADER false );

DROP TABLE IF EXISTS siret;
CREATE TABLE siret (
  siren TEXT,
  nic TEXT
);

\copy siret FROM 'data/siret.csv' ( FORMAT CSV, HEADER true, DELIMITER ',' , ENCODING 'latin-9' ) ;

DROP TABLE IF EXISTS lorem_ipsum;
CREATE TABLE lorem_ipsum (
  paragraph TEXT
);

\copy lorem_ipsum FROM 'data/lorem_ipsum.csv' WITH ( FORMAT CSV, HEADER false , DELIMITER E'\t' );

