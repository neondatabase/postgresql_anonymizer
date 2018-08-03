
--BEGIN;

--
-- First names
-- A bit of cleaning is required
-- 

DROP TABLE IF EXISTS first_names_raw;
CREATE TEMPORARY TABLE first_names_raw (
	first_name TEXT,
	gender TEXT,
	language TEXT,
	frequency FLOAT
);

\copy first_names_raw from 'data/first_names.csv' with ( FORMAT CSV, HEADER true, DELIMITER ';', ENCODING 'latin-9' );

DROP TABLE if EXISTS first_names;
CREATE TABLE first_names AS
SELECT 
	first_name,
	(CASE WHEN gender ~ 'm' THEN 1 ELSE 0 END)::boolean AS male,
	(CASE WHEN gender ~ 'f' THEN 1 ELSE 0 END)::boolean AS female,
	language
FROM first_names_raw;

-- 
-- Last names
-- Raw data is ok
--

DROP TABLE IF EXISTS last_name;                                                                                                                        
CREATE TABLE last_name (                                                                                                                               
    name TEXT                                                                                                                                          
);                                                                                                                                                     
                                                                                                                                                       
\copy last_name from 'data/last_names.csv';

--
-- Companies
-- No cleaning required
--


DROP TABLE IF EXISTS companies;
CREATE TABLE companies (
	name TEXT
);

\copy companies from 'data/companies.csv';

