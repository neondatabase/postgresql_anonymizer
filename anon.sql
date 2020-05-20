
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION anon" to load this file. \quit

--
-- Dependencies :
--  * tms_system_rows (should be available with all distributions of postgres)
--  * pgcrypto ( because PG10 does not include hashing functions )

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS anon.config;
CREATE TABLE anon.config (
    param TEXT UNIQUE NOT NULL,
    value TEXT
);

SELECT pg_catalog.pg_extension_config_dump('anon.config','');

COMMENT ON TABLE anon.config IS 'Anonymization and Masking settings';

-- We also use a secret table to store the hash seed and algorithm
DROP TABLE IF EXISTS anon.secret;
CREATE TABLE anon.secret (
    param TEXT UNIQUE NOT NULL,
    value TEXT
);
REVOKE ALL ON TABLE anon.secret FROM PUBLIC;

SELECT pg_catalog.pg_extension_config_dump('anon.secret','');

COMMENT ON TABLE anon.config IS 'Hashing secrets';

--
-- We use access methods to read/write the content of the `secret` table
-- The `get_secret_xxx()` function can be used with the security definer option
--
CREATE OR REPLACE FUNCTION anon.set_secret_salt(v TEXT)
RETURNS TEXT AS
$$
  INSERT INTO anon.secret(param,value)
  VALUES('salt',v)
  ON CONFLICT (param)
  DO
    UPDATE
    SET value=v
    WHERE EXCLUDED.param = 'salt'
  RETURNING value
$$
  LANGUAGE SQL
  RETURNS NULL ON NULL INPUT
  SECURITY INVOKER
;
REVOKE EXECUTE ON FUNCTION anon.set_secret_salt(TEXT)  FROM PUBLIC;

CREATE OR REPLACE FUNCTION anon.get_secret_salt()
RETURNS TEXT AS
$$
  SELECT value
  FROM anon.secret
  WHERE param = 'salt'
$$
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  SECURITY INVOKER
;
REVOKE EXECUTE ON FUNCTION anon.get_secret_salt()  FROM PUBLIC;

CREATE OR REPLACE FUNCTION anon.set_secret_algorithm(v TEXT)
RETURNS TEXT AS
$$
  INSERT INTO anon.secret(param,value)
  VALUES('algorithm',v)
  ON CONFLICT (param)
  DO
    UPDATE
    SET value=v
    WHERE EXCLUDED.param = 'algorithm'
  RETURNING value
$$
  LANGUAGE SQL
  RETURNS NULL ON NULL INPUT
  SECURITY INVOKER
;
REVOKE EXECUTE ON FUNCTION anon.set_secret_algorithm(TEXT)  FROM PUBLIC;

CREATE OR REPLACE FUNCTION anon.get_secret_algorithm()
RETURNS TEXT AS
$$
  SELECT value
  FROM anon.secret
  WHERE param = 'algorithm'
$$
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  SECURITY INVOKER
;
REVOKE EXECUTE ON FUNCTION anon.get_secret_algorithm()  FROM PUBLIC;



CREATE OR REPLACE FUNCTION anon.version()
RETURNS TEXT AS
$func$
  SELECT '0.7'::text AS version
$func$
  LANGUAGE SQL
  SECURITY INVOKER
;

-- name of the source schema
-- default value: 'public'
CREATE OR REPLACE FUNCTION anon.source_schema()
RETURNS TEXT AS
$$
WITH default_config(value) AS (
  VALUES ('public')
)
SELECT COALESCE(c.value, d.value)
FROM default_config d
LEFT JOIN anon.config AS c ON (c.param = 'sourceschema')
;
$$
LANGUAGE SQL STABLE SECURITY INVOKER;

-- name of the masking schema
-- default value: 'mask'
CREATE OR REPLACE FUNCTION anon.mask_schema()
RETURNS TEXT AS
$$
WITH default_config(value) AS (
  VALUES ('mask')
)
SELECT COALESCE(c.value, d.value)
FROM default_config d
LEFT JOIN anon.config AS c ON (c.param = 'maskschema')
;
$$
LANGUAGE SQL STABLE SECURITY INVOKER;



-------------------------------------------------------------------------------
-- Noise
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.add_noise_on_numeric_column(
  noise_table regclass,
  noise_column TEXT,
  ratio FLOAT
)
RETURNS BOOLEAN
AS $func$
DECLARE
  colname TEXT;
BEGIN

  -- Stop if noise_column does not exist
  SELECT column_name INTO colname
  FROM information_schema.columns
  WHERE table_name=noise_table::TEXT
  AND column_name=noise_column::TEXT;
  IF colname IS NULL THEN
    RAISE WARNING 'Column ''%'' is not present in table ''%''.',
                    noise_column,
                    noise_table;
    RETURN FALSE;
  END IF;

  EXECUTE format('
     UPDATE %I
     SET %I = %I *  (1+ (2 * random() - 1 ) * %L) ;
     ', noise_table, noise_column, noise_column, ratio
);
RETURN TRUE;
END;
$func$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.add_noise_on_datetime_column(
  noise_table regclass,
  noise_column TEXT,
  variation INTERVAL
)
RETURNS BOOLEAN
AS $func$
DECLARE
  colname TEXT;
BEGIN

  -- Stop if noise_column does not exist
  SELECT column_name INTO colname
  FROM information_schema.columns
  WHERE table_name=noise_table::TEXT
  AND column_name=noise_column::TEXT;
  IF colname IS NULL THEN
    RAISE WARNING 'Column ''%'' is not present in table ''%''.',
                  noise_column,
                  noise_table;
    RETURN FALSE;
  END IF;

  EXECUTE format('UPDATE %I SET %I = %I + (2 * random() - 1 ) * ''%s''::INTERVAL',
                  noise_table,
                  noise_column,
                  noise_column,
                  variation
  );
  RETURN TRUE;
END;
$func$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- "on the fly" noise
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value BIGINT,
  ratio DOUBLE PRECISION
)
 RETURNS BIGINT
AS $func$
SELECT (noise_value * (1.0-(2.0 * random() - 1.0 ) * ratio))::BIGINT
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value INTEGER,
  ratio DOUBLE PRECISION
)
 RETURNS INTEGER
AS $func$
SELECT (noise_value * (1.0-(2.0 * random() - 1.0 ) * ratio))::INTEGER
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value DOUBLE PRECISION,
  ratio DOUBLE PRECISION
)
 RETURNS DOUBLE PRECISION
AS $func$
SELECT (noise_value * (1.0-(2.0 * random() - 1.0 ) * ratio))::FLOAT
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value DATE,
  noise_range INTERVAL
)
 RETURNS DATE
AS $func$
SELECT (noise_value + (2.0 * random() - 1.0 ) * noise_range)::DATE
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value TIMESTAMP WITHOUT TIME ZONE,
  noise_range INTERVAL
)
 RETURNS TIMESTAMP WITHOUT TIME ZONE
AS $func$
SELECT noise_value + (2.0 * random() - 1.0) * noise_range
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.noise(
  noise_value TIMESTAMP WITH TIME ZONE,
  noise_range INTERVAL
)
 RETURNS TIMESTAMP WITH TIME ZONE
AS $func$
SELECT noise_value + (2.0 * random() - 1.0) * noise_range
$func$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- Shuffle
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.shuffle_column(
  shuffle_table regclass,
  shuffle_column NAME,
  primary_key NAME
)
RETURNS BOOLEAN
AS $func$
DECLARE
  colname TEXT;
BEGIN
  -- Stop if shuffle_column does not exist
  SELECT column_name INTO colname
  FROM information_schema.columns
  WHERE table_name=shuffle_table::TEXT
  AND column_name=shuffle_column::TEXT;
  IF colname IS NULL THEN
    RAISE WARNING 'Column ''%'' is not present in table ''%''.',
                  shuffle_column,
                  shuffle_table;
    RETURN FALSE;
  END IF;

  -- Stop if primary_key does not exist
  SELECT column_name INTO colname
  FROM information_schema.columns
  WHERE table_name=shuffle_table::TEXT
  AND column_name=primary_key::TEXT;
  IF colname IS NULL THEN
    RAISE WARNING 'Column ''%'' is not present in table ''%''.',
                  primary_key,
                  shuffle_table;
    RETURN FALSE;
  END IF;

  -- shuffle
  EXECUTE format('
  WITH s1 AS (
    -- shuffle the primary key
    SELECT row_number() over (order by random()) n,
           %3$I AS pkey
    FROM %1$I
  ),
  s2 AS (
    -- shuffle the column
    SELECT row_number() over (order by random()) n,
           %2$I AS val
    FROM %1$I
  )
  UPDATE %1$I
  SET %2$I = s2.val
  FROM s1 JOIN s2 ON s1.n = s2.n
  WHERE %3$I = s1.pkey;
  ', shuffle_table, shuffle_column, primary_key);
  RETURN TRUE;
END;
$func$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- Fake Data
-------------------------------------------------------------------------------

-- Cities, Regions & Countries
DROP TABLE IF EXISTS anon.city;
CREATE TABLE anon.city (
  oid SERIAL,
  name TEXT,
  country TEXT,
  subcountry TEXT,
  geonameid TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.city','');

COMMENT ON TABLE anon.city IS 'Cities, Regions & Countries';

-- Companies
DROP TABLE IF EXISTS anon.company;
CREATE TABLE anon.company (
  oid SERIAL,
  name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.company','');

-- Email
DROP TABLE IF EXISTS anon.email;
CREATE TABLE anon.email (
  oid SERIAL,
  address TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.email','');

-- First names
DROP TABLE IF EXISTS anon.first_name;
CREATE TABLE anon.first_name (
  oid SERIAL,
  first_name TEXT,
  male BOOLEAN,
  female BOOLEAN,
  language TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.first_name','');

-- IBAN
DROP TABLE IF EXISTS anon.iban;
CREATE TABLE anon.iban (
  oid SERIAL,
  id TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.iban','');

-- Last names
DROP TABLE IF EXISTS anon.last_name;
CREATE TABLE anon.last_name (
  oid SERIAL,
  name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.last_name','');

-- SIRET
DROP TABLE IF EXISTS anon.siret;
CREATE TABLE anon.siret (
  oid SERIAL,
  siren TEXT,
  nic TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.siret','');

-- Lorem Ipsum
DROP TABLE IF EXISTS anon.lorem_ipsum;
CREATE TABLE anon.lorem_ipsum (
  oid SERIAL,
  paragraph TEXT
);
SELECT pg_catalog.pg_extension_config_dump('anon.lorem_ipsum','');

-- ADD NEW TABLE HERE


-------------------------------------------------------------------------------
-- Discovery / Scanning
-------------------------------------------------------------------------------

-- https://labkey.med.ualberta.ca/labkey/_webdav/REDCap%20Support/@wiki/identifiers/identifiers.html?listing=html

CREATE TABLE anon.identifiers_category(
  id INTEGER,
  name TEXT,
  direct_identifier BOOLEAN,
  anon_function TEXT,
  PRIMARY KEY(name)
);

COMMENT ON TABLE anon.identifiers_category
IS 'Generic identifiers categories based the HIPAA classification';


CREATE TABLE anon.identifier(
  lang TEXT,
  attname TEXT,
  fk_identifiers_category TEXT,
  PRIMARY KEY(attname,lang),
  FOREIGN KEY (fk_identifiers_category)
    REFERENCES anon.identifiers_category(name)
);

COMMENT ON TABLE anon.identifier
IS 'Dictionnary of common identifiers field names';

CREATE OR REPLACE FUNCTION anon.detect(
  dict_lang TEXT DEFAULT 'en_US'
)
RETURNS TABLE (
  table_name REGCLASS,
  column_name NAME,
  identifiers_category TEXT,
  direct BOOLEAN
)
AS $func$
BEGIN
  IF not anon.isloaded() THEN
    RAISE NOTICE 'The dictionnaries are not loaded.'
      USING HINT = 'You probably need to run ''SELECT anon.load()'' ';
  END IF;

RETURN QUERY SELECT
  a.attrelid::regclass,
  a.attname,
  ic.name,
  ic.direct_identifier
FROM pg_catalog.pg_attribute a
JOIN anon.identifier fn
  ON lower(a.attname) = fn.attname
JOIN anon.identifiers_category ic
  ON fn.fk_identifiers_category = ic.name
JOIN pg_catalog.pg_class c
  ON c.oid = a.attrelid
WHERE fn.lang = dict_lang
  AND c.relnamespace IN ( -- exclude the extension tables and the catalog
        SELECT oid
        FROM pg_namespace
        WHERE nspname NOT LIKE 'pg_%'
        AND nspname NOT IN  ( 'information_schema',
                              'anon',
                              anon.mask_schema()
                            )
      )
;
END;
$func$
LANGUAGE plpgsql IMMUTABLE;


-------------------------------------------------------------------------------
-- Functions : LOAD / UNLOAD
-------------------------------------------------------------------------------

-- ADD unit tests in tests/sql/load.sql

-- load fake data from a given path
CREATE OR REPLACE FUNCTION anon.load(
  datapath TEXT
)
RETURNS BOOLEAN
AS $func$
DECLARE
  datapath_regexp  TEXT;
  datapath_check TEXT;
BEGIN
  IF anon.isloaded() THEN
    RAISE NOTICE 'The anon extension is already loaded.';
    RETURN TRUE;
  END IF;

  -- This check does not work with PG10 and below
  -- because absolute paths are not allowed
  --SELECT * INTO  datapath_check
  --FROM pg_stat_file(datapath, missing_ok := TRUE )
  --WHERE isdir;

  -- This works with all current version of Postgres
  datapath_regexp := '^\/$|(^(?=\/)|^\.|^\.\.)(\/(?=[^/\0])[^/\0]+)*\/?$';
  SELECT regexp_matches(datapath,datapath_regexp) INTO datapath_check;

  -- Stop if is the directory does not exist
  IF datapath_check IS NULL THEN
    RAISE WARNING 'The path ''%'' is not correct. Data is not loaded.', datapath;
    RETURN FALSE;
  END IF;

  -- Identifiers dictionnaries
  EXECUTE 'COPY anon.identifiers_category FROM '|| quote_literal(datapath ||'/identifiers_category.csv');
  EXECUTE 'COPY anon.identifier FROM '|| quote_literal(datapath ||'/identifier_fr_FR.csv');
  EXECUTE 'COPY anon.identifier FROM '|| quote_literal(datapath ||'/identifier_en_US.csv');

  -- ADD NEW TABLE HERE
  EXECUTE 'COPY anon.city(name,country,subcountry,geonameid) FROM '
    || quote_literal(datapath ||'/city.csv');

  EXECUTE 'COPY anon.company(name) FROM '
    || quote_literal(datapath ||'/company.csv');

  EXECUTE 'COPY anon.email(address) FROM '
    || quote_literal(datapath ||'/email.csv');

  EXECUTE 'COPY anon.first_name(first_name,male,female,language) FROM '
    || quote_literal(datapath ||'/first_name.csv');

  EXECUTE 'COPY anon.iban(id) FROM '
    || quote_literal(datapath ||'/iban.csv');

  EXECUTE 'COPY anon.last_name(name) FROM '
    || quote_literal(datapath ||'/last_name.csv');

  EXECUTE 'COPY anon.siret(siren, nic) FROM '
    || quote_literal(datapath ||'/siret.csv');

  EXECUTE 'COPY anon.lorem_ipsum(paragraph) FROM '
    || quote_literal(datapath ||'/lorem_ipsum.csv');

  RETURN TRUE;

  EXCEPTION
    WHEN undefined_file THEN
      RAISE WARNING 'The path ''%'' does not exist. Data is not loaded.', datapath;
    RETURN FALSE;
END;
$func$
LANGUAGE PLPGSQL VOLATILE SECURITY INVOKER;

-- If no path given, use the default data
CREATE OR REPLACE FUNCTION anon.load()
RETURNS BOOLEAN
AS $$
    WITH conf AS (
        -- find the local extension directory
        SELECT setting AS sharedir
        FROM pg_config
        WHERE name = 'SHAREDIR'
    )
    SELECT
      anon.load(conf.sharedir || '/extension/anon/'),
      -- if the secret salt is NULL, generate a random salt
      COALESCE(
          anon.get_secret_salt(),
          anon.set_secret_salt(md5(random()::TEXT))
      ),
      -- if the secret hash algo is NULL, we use sha512 by default
      COALESCE(
          anon.get_secret_algorithm(),
          anon.set_secret_algorithm('sha512')
      )
    FROM conf;
    SELECT TRUE;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- True, the fake data is already here
CREATE OR REPLACE FUNCTION anon.isloaded()
RETURNS BOOL
AS $$
  SELECT count(*)::INT::BOOL
  FROM (   SELECT 1 FROM anon.siret
     UNION SELECT 1 FROM anon.company
     UNION SELECT 1 FROM anon.last_name
     UNION SELECT 1 FROM anon.city
     UNION SELECT 1 FROM anon.email
     UNION SELECT 1 FROM anon.first_name
     UNION SELECT 1 FROM anon.iban
     UNION SELECT 1 FROM anon.lorem_ipsum
     -- ADD NEW TABLE HERE
     LIMIT 1
  ) t
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- remove all fake data
CREATE OR REPLACE FUNCTION anon.unload()
RETURNS BOOLEAN AS $$
    TRUNCATE anon.city;
    TRUNCATE anon.company;
    TRUNCATE anon.email;
    TRUNCATE anon.first_name;
    TRUNCATE anon.iban;
    TRUNCATE anon.last_name;
    TRUNCATE anon.siret;
    TRUNCATE anon.lorem_ipsum;
    TRUNCATE anon.secret;
    -- ADD NEW TABLE HERE
    SELECT TRUE;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
--- Generic hashing
-------------------------------------------------------------------------------

-- This is a wrapper around the pgcrypto digest function
-- Standard algorithms are md5, sha1, sha224, sha256, sha384 and sha512.
-- https://www.postgresql.org/docs/current/pgcrypto.html
CREATE OR REPLACE FUNCTION anon.digest(
  seed TEXT,
  salt TEXT,
  algorithm TEXT
)
RETURNS TEXT AS $$
  SELECT encode(digest(concat(seed,salt),algorithm),'hex');
$$
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  SECURITY INVOKER
;


CREATE OR REPLACE FUNCTION anon.hash(
  seed TEXT
)
RETURNS TEXT AS $$
  -- https://www.postgresql.org/docs/current/pgcrypto.html
  SELECT anon.digest(
    seed,
    anon.get_secret_salt(),
    anon.get_secret_algorithm()
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  SECURITY DEFINER
--  SET search_path = pg_catalog,pg_temp
;
-- FIXME : conflict between search_path and public.digest
-- https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY

-------------------------------------------------------------------------------
-- Random Generic Data
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.random_string(
  l integer
)
RETURNS text
AS $$
  SELECT array_to_string(
    array(
        select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
                      ((random()*(36-1)+1)::integer)
                      ,1)
        from generate_series(1,l)
    ),''
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- Zip code
CREATE OR REPLACE FUNCTION anon.random_zip()
RETURNS text
AS $$
  SELECT array_to_string(
         array(
                select substr('0123456789',((random()*(10-1)+1)::integer),1)
                from generate_series(1,5)
            ),''
          );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;


-- date

CREATE OR REPLACE FUNCTION anon.random_date_between(
  date_start timestamp WITH TIME ZONE,
  date_end timestamp WITH TIME ZONE
)
RETURNS timestamp WITH TIME ZONE AS $$
    SELECT (random()*(date_end-date_start))::interval+date_start;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION random_date()
RETURNS timestamp with time zone AS $$
    SELECT anon.random_date_between('1900-01-01'::timestamp with time zone,now());
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;


-- integer

CREATE OR REPLACE FUNCTION anon.random_int_between(
  int_start INTEGER,
  int_stop INTEGER
)
RETURNS INTEGER AS $$
    SELECT CAST ( random()*(int_stop-int_start)+int_start AS INTEGER );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_bigint_between(
  int_start BIGINT,
  int_stop BIGINT
)
RETURNS BIGINT AS $$
    SELECT CAST ( random()*(int_stop-int_start)+int_start AS BIGINT );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_phone(
  phone_prefix TEXT DEFAULT '0'
)
RETURNS TEXT AS $$
  SELECT  phone_prefix
          || CAST(anon.random_int_between(100000000,999999999) AS TEXT)
          AS "phone";
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

--
-- hashing a seed with a random salt
--
CREATE OR REPLACE FUNCTION anon.random_hash(
  seed TEXT
)
RETURNS TEXT AS
$$
  SELECT anon.digest(
    seed,
    anon.random_string(6),
    anon.get_secret_algorithm()
  );
$$
  LANGUAGE SQL
  VOLATILE
  SECURITY DEFINER -- FIXME: set search_path
  RETURNS NULL ON NULL INPUT
;

-------------------------------------------------------------------------------
-- FAKE data
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION anon.fake_first_name()
RETURNS TEXT AS $$
    SELECT first_name
    FROM anon.first_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_last_name()
RETURNS TEXT AS $$
    SELECT name
    FROM anon.last_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_email()
RETURNS TEXT AS $$
    SELECT address
    FROM anon.email
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_city_in_country(
  country_name TEXT
)
RETURNS TEXT AS $$
    SELECT name
    FROM anon.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_city()
RETURNS TEXT AS $$
    SELECT name
    FROM anon.city
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_region_in_country(
  country_name TEXT
)
RETURNS TEXT AS $$
    SELECT subcountry
    FROM anon.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_region()
RETURNS TEXT AS $$
    SELECT subcountry
    FROM anon.city
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_country()
RETURNS TEXT AS $$
    SELECT country
    FROM anon.city
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_company()
RETURNS TEXT AS $$
    SELECT name
    FROM anon.company
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_iban()
RETURNS TEXT AS $$
    SELECT id
    FROM anon.iban
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_siren()
RETURNS TEXT AS $$
    SELECT siren
    FROM anon.siret
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.fake_siret()
RETURNS TEXT AS $$
    SELECT siren||nic
    FROM anon.siret
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- Lorem Ipsum
-- Usage:
--   `SELECT anon.lorem_ipsum()` returns 5 paragraphs
--   `SELECT anon.lorem_ipsum(2)` return 2 paragraphs
--   `SELECT anon.lorem_ipsum( paragraph := 4 )` return 4 paragraphs
--   `SELECT anon.lorem_ipsum( words := 20 )` return 20 words
--   `SELECT anon.lorem_ipsum( characters := 7 )` return 7 characters
--
CREATE OR REPLACE FUNCTION anon.lorem_ipsum(
  paragraphs INTEGER DEFAULT 5,
  words INTEGER DEFAULT 0,
  characters INTEGER DEFAULT 0
)
RETURNS TEXT AS $$
WITH
-- First let's shuffle the lorem_ipsum table
randomized_lorem_ipsum AS (
  SELECT *
  FROM anon.lorem_ipsum
  ORDER BY RANDOM()
),
-- if `characters` is defined,
-- then the limit is the number of characters
-- else return NULL
cte_characters AS (
  SELECT
    CASE characters
      WHEN 0
      THEN NULL
      ELSE substring( c.agg_paragraphs for characters )
    END AS n_characters
  FROM (
    SELECT string_agg(paragraph,E'\n') AS agg_paragraphs
    FROM randomized_lorem_ipsum
  ) AS c
),
-- if `characters` is not defined and if `words` defined,
-- then the limit is the number of words
-- else return NULL
cte_words AS (
  SELECT
    CASE words
      WHEN 0
      THEN NULL
      ELSE string_agg(w.unnested_words,' ')
    END AS n_words
  FROM (
    SELECT unnest(string_to_array(p.agg_paragraphs,' ')) as unnested_words
    FROM (
      SELECT string_agg(paragraph,E' \n') AS agg_paragraphs
      FROM randomized_lorem_ipsum
      ) AS p
    LIMIT words
  ) as w
),
-- if `characters` is notdefined and `words` is not defined,
-- then the limit is the number of paragraphs
cte_paragraphs AS (
  SELECT string_agg(l.paragraph,E'\n') AS n_paragraphs
  FROM (
    SELECT *
    FROM randomized_lorem_ipsum
    LIMIT paragraphs
  ) AS l
)
SELECT COALESCE(
  cte_characters.n_characters,
  cte_words.n_words,
  cte_paragraphs.n_paragraphs
)
FROM
  cte_characters,
  cte_words,
  cte_paragraphs
;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

--
-- Backward compatibility with version 0.2.1 and earlier
--

CREATE OR REPLACE FUNCTION anon.random_first_name()
RETURNS TEXT AS $$ SELECT anon.fake_first_name() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;


CREATE OR REPLACE FUNCTION anon.random_last_name()
RETURNS TEXT AS $$ SELECT anon.fake_last_name() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_email()
RETURNS TEXT AS $$ SELECT anon.fake_email() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_city_in_country(
  country_name TEXT
)
RETURNS TEXT AS $$ SELECT anon.fake_city_in_country(country_name) $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_city()
RETURNS TEXT AS $$ SELECT anon.fake_city() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_region_in_country(
  country_name TEXT
)
RETURNS TEXT AS $$ SELECT anon.fake_region_in_country(country_name) $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_region()
RETURNS TEXT AS $$ SELECT anon.fake_region() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_country()
RETURNS TEXT AS $$ SELECT anon.fake_country() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_company()
RETURNS TEXT AS $$ SELECT anon.fake_company() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_iban()
RETURNS TEXT AS $$ SELECT anon.fake_iban() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_siren()
RETURNS TEXT AS $$ SELECT anon.fake_siren() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.random_siret()
RETURNS TEXT AS $$ SELECT anon.fake_siret() $$
LANGUAGE SQL VOLATILE SECURITY INVOKER;


-------------------------------------------------------------------------------
-- Pseudonymized data
-------------------------------------------------------------------------------

--
-- Convert an hexadecimal value to an integer
--
CREATE OR REPLACE FUNCTION anon.hex_to_int(
  hexval TEXT
)
RETURNS INT AS $$
DECLARE
    result  INT;
BEGIN
    EXECUTE 'SELECT x' || quote_literal(hexval) || '::INT' INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER;

--
-- Return a deterministic value inside a range of OID for a given seed+salt
--
CREATE OR REPLACE FUNCTION anon.projection_to_oid(
  seed TEXT,
  salt TEXT,
  last_oid BIGINT
)
RETURNS INT AS $$
  --
  -- get a md5 hash of the seed and then project it on a 0-to-1 scale
  -- then multiply by the latest oid
  -- which give a deterministic oid inside the range
  --
  -- This works because MD5 signatures values have a uniform distribution
  --
  SELECT CAST(
    -- we use only the 6 first characters of the md5 signature
    -- and we divide by the max value : x'FFFFFF' = 16777215
    last_oid * anon.hex_to_int(md5(seed||salt)::char(6)) / 16777215.0
  AS INT )
$$
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  SECURITY INVOKER
;

CREATE OR REPLACE FUNCTION anon.pseudo_first_name(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT first_name
  FROM anon.first_name
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.first_name_oid_seq)
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  SECURITY DEFINER
  SET search_path = pg_catalog,pg_temp
;

CREATE OR REPLACE FUNCTION anon.pseudo_last_name(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT name
  FROM anon.last_name
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.last_name_oid_seq)
  );
$$
  LANGUAGE SQL
  IMMUTABLE
  SECURITY DEFINER
  SET search_path = pg_catalog,pg_temp
;


CREATE OR REPLACE FUNCTION anon.pseudo_email(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT address
  FROM anon.email
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.email_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_city(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT name
  FROM anon.city
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.city_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_region(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT subcountry
  FROM anon.city
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.city_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_country(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT country
  FROM anon.city
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.city_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_company(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT name
  FROM anon.company
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.company_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_iban(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT id
  FROM anon.iban
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.iban_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_siren(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT siren
  FROM anon.siret
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.siret_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

CREATE OR REPLACE FUNCTION anon.pseudo_siret(
  seed TEXT,
  salt TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
  SELECT siren||nic
  FROM anon.siret
  WHERE oid = anon.projection_to_oid(
    seed,
    COALESCE(salt,anon.get_secret_salt()),
    (SELECT last_value FROM anon.siret_oid_seq)
  );
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;




-------------------------------------------------------------------------------
-- Partial Scrambling
-------------------------------------------------------------------------------

--
-- partial('abcdefgh',1,'xxxx',3) will return 'axxxxfgh';
--
CREATE OR REPLACE FUNCTION anon.partial(
  ov TEXT,
  prefix INT,
  padding TEXT,
  suffix INT
)
RETURNS TEXT AS $$
  SELECT substring(ov FROM 1 FOR prefix)
      || padding
      || substring(ov FROM (length(ov)-suffix+1) FOR suffix);
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

--
-- email('daamien@gmail.com') will becomme 'da******@gm******.com'
--
CREATE OR REPLACE FUNCTION anon.partial_email(
  ov TEXT
)
RETURNS TEXT AS $$
-- This is an oversimplistic way to scramble an email address
-- The main goal is to avoid any complex regexp
-- by splitting the job into simpler tasks
  SELECT substring(regexp_replace(ov, '@.*', '') FROM 1 FOR 2) -- da
      || '******'
      || '@'
      || substring(regexp_replace(ov, '.*@', '') FROM 1 FOR 2) -- gm
      || '******'
      || '.'
      || regexp_replace(ov, '.*\.', '') -- com
  ;
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;


-------------------------------------------------------------------------------
-- Masking Rules Management
-- This is the common metadata used by the 3 main features :
-- anonymize(), dump() and dynamic masking engine
-------------------------------------------------------------------------------

-- List of all the masked columns
CREATE OR REPLACE VIEW anon.pg_masking_rules AS
WITH const AS (
  SELECT
    '%MASKED +WITH +FUNCTION +#"%#(%#)#"%'::TEXT
      AS pattern_mask_column_function,
    'MASKED +WITH +VALUE +([''$A-Za-z0-9]*) ?'::TEXT
      AS pattern_mask_column_value
),
rules_from_comments AS (
SELECT
  a.attrelid,
  a.attnum,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  pg_catalog.col_description(a.attrelid, a.attnum),
  substring(  pg_catalog.col_description(a.attrelid, a.attnum)
              from k.pattern_mask_column_function for '#')
    AS masking_function,
  substring(  pg_catalog.col_description(a.attrelid, a.attnum)
              from k.pattern_mask_column_value)
    AS masking_value,
  0 AS priority --low priority for the comment syntax
FROM const k,
     pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (   pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
    OR  pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_value
    )
),
rules_from_seclabels AS (
SELECT
  sl.objoid AS attrelid,
  sl.objsubid  AS attnum,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  sl.label AS col_description,
  substring(sl.label from k.pattern_mask_column_function for '#')  AS masking_function,
  substring(sl.label from k.pattern_mask_column_value )  AS masking_value,
  100 AS priority -- high priority for the security label syntax
FROM const k,
     pg_catalog.pg_seclabel sl
JOIN pg_catalog.pg_class c ON sl.classoid = c.tableoid AND sl.objoid = c.oid
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND sl.objsubid = a.attnum
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (   sl.label SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
    OR  sl.label SIMILAR TO k.pattern_mask_column_value
    )
AND sl.provider = 'anon' -- this is hard-coded in anon.c
),
rules_from_all AS (
SELECT * FROM rules_from_comments
UNION
SELECT * FROM rules_from_seclabels
)
-- DISTINCT will keep just the 1st rule for each column based on priority,
SELECT DISTINCT ON (attrelid, attnum) *,
    COALESCE(masking_function, masking_value) AS masking_filter
FROM rules_from_all
ORDER BY attrelid, attnum, priority DESC
;

-- Compatibility with version 0.3 and earlier
CREATE OR REPLACE VIEW anon.pg_masks AS
SELECT * FROM anon.pg_masking_rules
;


-------------------------------------------------------------------------------
-- In-Place Anonymization
-------------------------------------------------------------------------------

-- Replace masked data in a column
CREATE OR REPLACE FUNCTION anon.anonymize_column(
  tablename REGCLASS,
  colname NAME
)
RETURNS BOOLEAN AS
$$
DECLARE
  mf TEXT; -- masking_filter can be either a function or a value
  mf_is_a_faking_function BOOLEAN;
BEGIN
  SET CONSTRAINTS ALL DEFERRED;
  SELECT masking_filter INTO mf
  FROM anon.pg_masking_rules
  WHERE attrelid = tablename::OID
  AND attname = colname;

  IF mf IS NULL THEN
    RAISE WARNING 'There is no masking rule for column % in table %',
                  colname,
                  tablename;
    RETURN FALSE;
  END IF;

  SELECT mf LIKE 'anon.fake_%' INTO mf_is_a_faking_function;
  IF mf_is_a_faking_function AND not anon.isloaded() THEN
    RAISE NOTICE 'The faking data is not loaded.'
      USING HINT = 'You probably need to run ''SELECT anon.load()'' ';
  END IF;

  RAISE DEBUG 'Anonymize %.% with %', tablename,colname, mf;
  EXECUTE format('UPDATE %s SET %I = %s', tablename,colname, mf);

  RETURN TRUE;
END;
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;


-- Replace masked data in a table
CREATE OR REPLACE FUNCTION anon.anonymize_table(tablename REGCLASS)
RETURNS BOOLEAN AS
$$
  -- bool_or is required to aggregate all tuples
  -- otherwise only the first masking rule is applied
  -- see issue #114
  SELECT bool_or(anon.anonymize_column(tablename,attname))
  FROM anon.pg_masking_rules
  WHERE attrelid::regclass=tablename;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- Walk through all masked columns and permanently apply the mask
CREATE OR REPLACE FUNCTION anon.anonymize_database()
RETURNS BOOLEAN AS
$$
  SELECT bool_or(anon.anonymize_column(attrelid::REGCLASS,attname))
  FROM anon.pg_masking_rules;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- Backward compatibility with version 0.2
CREATE OR REPLACE FUNCTION anon.static_substitution()
RETURNS BOOLEAN AS
$$
  SELECT anon.anonymize_database();
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- Dynamic Masking
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/masking.sql
--   * tests/sql/hasmask.sql

-- True if the role is masked
CREATE OR REPLACE FUNCTION anon.hasmask(
  role REGROLE
)
RETURNS BOOLEAN AS
$$
SELECT bool_or(m.masked)
FROM (
  -- Rule from COMMENT
  SELECT shobj_description(role,'pg_authid') SIMILAR TO '%MASKED%' AS masked
  UNION
  -- Rule from SECURITY LABEL
  SELECT label ILIKE 'MASKED' AS masked
  FROM pg_catalog.pg_shseclabel
  WHERE  objoid = role
  AND provider = 'anon' -- this is hard coded in anon.c
  UNION
  -- return FALSE if the 2 SELECT above are empty
  SELECT FALSE as masked --
) AS m
$$
LANGUAGE SQL STABLE SECURITY INVOKER;

-- DEPRECATED : use directly `hasmask(oid::REGROLE)` instead
-- Adds a `hasmask` column to the pg_roles catalog
CREATE OR REPLACE VIEW anon.pg_masked_roles AS
SELECT r.*, anon.hasmask(r.oid::REGROLE)
FROM pg_catalog.pg_roles r
;

-- Display all columns of the relation with the masking function (if any)
CREATE OR REPLACE FUNCTION anon.mask_columns(
  source_relid OID
)
RETURNS TABLE (
    attname NAME,
    masking_filter TEXT,
    format_type TEXT
) AS
$$
SELECT
  a.attname::NAME, -- explicit cast for PG 9.6
  m.masking_filter,
  m.format_type
FROM pg_attribute a
LEFT JOIN  anon.pg_masking_rules m
        ON m.attrelid = a.attrelid
        AND m.attname = a.attname
WHERE  a.attrelid = source_relid
AND    a.attnum > 0 -- exclude ctid, cmin, cmax
AND    NOT a.attisdropped
ORDER BY a.attnum
;
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- build a masked view for each table
-- /!\ Disable the Event Trigger before calling this :-)
-- We can't use the namespace oids because the mask schema may not be present
CREATE OR REPLACE FUNCTION  anon.mask_create()
RETURNS SETOF VOID AS
$$
BEGIN
  -- Walk through all tables in the source schema
  PERFORM anon.mask_create_view(oid)
  FROM pg_class
  WHERE relnamespace=anon.sourceschema()::regnamespace
  AND relkind = 'r' -- relations only
  ;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;


-- get the "select filters" that will mask the real data of a table
CREATE OR REPLACE FUNCTION anon.mask_filters(
  relid OID
)
RETURNS TEXT AS
$$
DECLARE
    m RECORD;
    expression TEXT;
    comma TEXT;
BEGIN
    expression := '';
    comma := '';
    FOR m IN SELECT * FROM anon.mask_columns(relid)
    LOOP
        expression := expression || comma;
        IF m.masking_filter IS NULL THEN
            -- No masking rule found
            expression := expression || quote_ident(m.attname);
        ELSE
            -- use the masking filter instead of the original value
            -- the masking filter is casted into the column type
            expression := expression || format('CAST(%s AS %s) AS %s',
                                                m.masking_filter,
                                                m.format_type,
                                                quote_ident(m.attname)
                                              );
        END IF;
        comma := ',';
    END LOOP;
  RETURN expression;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- Build a masked view for a table
CREATE OR REPLACE FUNCTION anon.mask_create_view(
  relid OID
)
RETURNS BOOLEAN AS
$$
BEGIN
  EXECUTE format('CREATE OR REPLACE VIEW "%s".%s AS SELECT %s FROM %s',
                                  anon.mask_schema(),
                                  (SELECT quote_ident(relname) FROM pg_class WHERE relid = oid),
                                  anon.mask_filters(relid),
                                  relid::REGCLASS);
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- Remove a masked view for a given table
CREATE OR REPLACE FUNCTION anon.mask_drop_view(
  relid OID
)
RETURNS BOOLEAN AS
$$
BEGIN
  EXECUTE format('DROP VIEW "%s".%s;', anon.mask_schema(),
                  (SELECT quote_ident(relname) FROM pg_class WHERE relid = oid)
  );
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- Activate the masking engine
CREATE OR REPLACE FUNCTION anon.start_dynamic_masking(
  sourceschema TEXT DEFAULT 'public',
  maskschema TEXT DEFAULT 'mask',
  autoload BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN
  -- Load default config values
  INSERT INTO anon.config
  VALUES
  ('sourceschema','public'),
  ('maskschema', 'mask')
  ON CONFLICT DO NOTHING
  ;

  -- Load faking data
  SELECT anon.isloaded() AS loaded INTO r;
  IF NOT autoload THEN
    RAISE DEBUG 'Autoload is disabled.';
  ELSEIF r.loaded THEN
    RAISE DEBUG 'Anon data is already loaded.';
  ELSE
    PERFORM anon.load();
  END IF;

  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', maskschema);
  EXECUTE format('UPDATE anon.config SET value=''%s'' WHERE param=''sourceschema'';', sourceschema);
  EXECUTE format('UPDATE anon.config SET value=''%s'' WHERE param=''maskschema'';', maskschema);

  PERFORM anon.mask_update();

  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- Backward compatibility with version 0.2
CREATE OR REPLACE FUNCTION anon.mask_init(
  sourceschema TEXT DEFAULT 'public',
  maskschema TEXT DEFAULT 'mask',
  autoload BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN AS
$$
SELECT anon.start_dynamic_masking(sourceschema,maskschema,autoload);
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- this is opposite of start_dynamic_masking()
CREATE OR REPLACE FUNCTION anon.stop_dynamic_masking()
RETURNS BOOLEAN AS
$$
BEGIN
  PERFORM anon.mask_disable();

  -- Walk through all tables in the source schema and drop the masking view
  PERFORM anon.mask_drop_view(oid)
  FROM pg_class
  WHERE relnamespace=anon.source_schema()::regnamespace
  AND relkind = 'r' -- relations only
  ;

  -- Walk through all masked roles and remove their masl
  PERFORM anon.unmask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE anon.hasmask(oid::REGROLE);

  -- Erase the config
  DELETE FROM anon.config WHERE param='sourceschema';
  DELETE FROM anon.config WHERE param='maskschema';

  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;



-- This is run after all DDL query
CREATE OR REPLACE FUNCTION anon.mask_trigger()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Functions cannot return EVENT_TRIGGER,
-- we're forced to write a plpgsql function
BEGIN
  PERFORM anon.mask_update();
END
$$
LANGUAGE plpgsql SECURITY INVOKER;


-- Mask a specific role
CREATE OR REPLACE FUNCTION anon.mask_role(
  maskedrole REGROLE
)
RETURNS BOOLEAN AS
$$
DECLARE
  sourceschema REGNAMESPACE;
  maskschema REGNAMESPACE;
BEGIN
  SELECT anon.source_schema()::REGNAMESPACE INTO sourceschema;
  SELECT anon.mask_schema()::REGNAMESPACE INTO maskschema;
  RAISE DEBUG 'Mask role % (% -> %)', maskedrole, sourceschema, maskschema;
  -- The masked role cannot read the authentic data in the source schema
  EXECUTE format('REVOKE ALL ON SCHEMA %s FROM %s', sourceschema, maskedrole);
  -- The masked role can use the anon schema (except the secrets)
  EXECUTE format('GRANT USAGE ON SCHEMA anon TO %s', maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA anon TO %s', maskedrole);
  EXECUTE format('REVOKE ALL ON TABLE anon.secret FROM %s',  maskedrole);
  -- The masked role can use the masking schema
  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', maskschema, maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s', maskschema, maskedrole);
  -- This is how we "trick" the masked role
  EXECUTE format('ALTER ROLE %s SET search_path TO %s,%s;', maskedrole, maskschema,sourceschema);
  RETURN TRUE;
END
$$
LANGUAGE plpgsql SECURITY INVOKER;

-- Remove (partially) the mask of a specific role
CREATE OR REPLACE FUNCTION anon.unmask_role(
  maskedrole REGROLE
)
RETURNS BOOLEAN AS
$$
BEGIN
  -- we dont know what priviledges this role had before putting his mask on
  -- so we keep most of the priviledges as they are and let the
  -- administrator restore the correct access right.
  RAISE NOTICE 'The previous priviledges of ''%'' are not restored. You need to grant them manually.', maskedrole;
  -- restore default search_path
  EXECUTE format('ALTER ROLE %s RESET search_path;', maskedrole);
  RETURN TRUE;
END
$$
LANGUAGE plpgsql SECURITY INVOKER;


-- load the event trigger
CREATE OR REPLACE FUNCTION anon.mask_enable()
RETURNS BOOLEAN AS
$$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_event_trigger WHERE evtname='anon_mask_update'
  )
  THEN
    CREATE EVENT TRIGGER anon_mask_update ON ddl_command_end
    EXECUTE PROCEDURE anon.mask_trigger();
  ELSE
    RAISE DEBUG 'event trigger "anon_mask_update" already exists: skipping';
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- unload the event trigger
CREATE OR REPLACE FUNCTION anon.mask_disable()
RETURNS BOOLEAN AS
$$
BEGIN
  IF EXISTS (
    SELECT FROM pg_event_trigger WHERE evtname='anon_mask_update'
  )
  THEN
    DROP EVENT TRIGGER IF EXISTS anon_mask_update;
  ELSE
    RAISE DEBUG 'event trigger "anon_mask_update" does not exist: skipping';
  RETURN FALSE;
  END IF;
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;

-- Rebuild the dynamic masking views and masked roles from scratch
CREATE OR REPLACE FUNCTION anon.mask_update()
RETURNS BOOLEAN AS
$$
  -- This DDL EVENT TRIGGER will launch new DDL statements
  -- therefor we have disable the EVENT TRIGGER first
  -- in order to avoid an infinite triggering loop :-)
  SELECT anon.mask_disable();

  -- Walk through all tables in the source schema
  -- and build a dynamic masking view
  SELECT anon.mask_create_view(oid)
  FROM pg_class
  WHERE relnamespace=anon.source_schema()::regnamespace
  AND relkind = 'r' -- relations only
  ;

  -- Walk through all masked roles and apply the restrictions
  SELECT anon.mask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE anon.hasmask(oid::REGROLE);

  -- Restore the mighty DDL EVENT TRIGGER
  SELECT anon.mask_enable();
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- Anonymous Dumps
-------------------------------------------------------------------------------

-- WARNING : this entire section is deprecated ! It kept for backward
-- compatibility and will probably be remove before version 1.0 is released


CREATE OR REPLACE FUNCTION anon.dump_ddl()
RETURNS TABLE (
    ddl TEXT
) AS
$$
    SELECT E'anon.dump_dll() is deprecated. Please use pg_dump_anon instead.'::TEXT
$$
LANGUAGE SQL SECURITY INVOKER;

-- generate the "COPY ... FROM STDIN" statement for a table
CREATE OR REPLACE FUNCTION anon.get_copy_statement(relid OID)
RETURNS TEXT AS
$$
DECLARE
  empty_table BOOLEAN;
  copy_statement TEXT;
  val TEXT;
  rec RECORD;
BEGIN
-- Stop right now if the table is empty
  EXECUTE format(E'SELECT true WHERE NOT EXISTS (SELECT 1 FROM %s);',
                                                    relid::REGCLASS)
  INTO empty_table;
  IF empty_table THEN
    RETURN '';
  END IF;

  --  /!\ cannot use COPY TO STDOUT in PL/pgSQL
  copy_statement := format(E' COPY %s
                              FROM STDIN
                              CSV QUOTE AS ''"''
                              DELIMITER '',''; \n',
                          relid::REGCLASS);
  FOR rec IN
    EXECUTE format(E'SELECT tmp::TEXT AS r FROM (SELECT %s FROM %s) AS tmp;',
                          anon.mask_filters(relid),
                          relid::REGCLASS
  )
  LOOP
  val := ltrim(rec.r,'(');
  val := rtrim(val,')');
  copy_statement := copy_statement || val || E'\n';
  END LOOP;
  copy_statement := copy_statement || E'\\.\n';
  RETURN copy_statement;
END
$$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;


-- export content of all the tables as COPY statements
CREATE OR REPLACE FUNCTION anon.dump_data()
RETURNS TABLE (
    data TEXT
) AS
$$
  SELECT anon.get_copy_statement(relid)
  FROM pg_stat_user_tables
  WHERE schemaname NOT IN ( 'anon' , anon.mask_schema() )
  ORDER BY  relid::regclass -- sort by name to force the dump order
$$
LANGUAGE SQL VOLATILE SECURITY INVOKER;

-- export the database schema + anonymized data
CREATE OR REPLACE FUNCTION anon.dump()
RETURNS TABLE (
  dump TEXT
) AS
$func$
BEGIN
  RAISE NOTICE 'This function is deprecated !'
    USING HINT = 'Use the pg_dump_anon command line instead.';

  RETURN QUERY
    SELECT anon.dump_ddl()
    UNION ALL -- ALL is required to maintain the lines order as appended
    SELECT anon.dump_data();
END;
$func$
LANGUAGE plpgsql VOLATILE SECURITY INVOKER;



-------------------------------------------------------------------------------
-- Generalization
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/generalization.sql

-- Transform an integer into a range of integer
CREATE OR REPLACE FUNCTION anon.generalize_int4range(
  val INTEGER,
  step INTEGER default 10
)
RETURNS INT4RANGE
AS $$
SELECT int4range(
    val / step * step,
    ((val / step)+1) * step
  );
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-- Transform a bigint into a range of bigint
CREATE OR REPLACE FUNCTION anon.generalize_int8range(
  val BIGINT,
  step BIGINT DEFAULT 10
)
RETURNS INT8RANGE
AS $$
SELECT int8range(
    val / step * step,
    ((val / step)+1) * step
  );
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-- Transform a numeric into a range of numeric
CREATE OR REPLACE FUNCTION anon.generalize_numrange(
  val NUMERIC,
  step INTEGER DEFAULT 10
)
RETURNS NUMRANGE
AS $$
WITH i AS (
  SELECT anon.generalize_int4range(val::INTEGER,step) as r
)
SELECT numrange(
    lower(i.r)::NUMERIC,
    upper(i.r)::NUMERIC
  )
FROM i
;
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-- Transform a timestamp with out timezone (ts) into a range of ts
-- the `step` option can have the following values
--        microseconds,milliseconds,second,minute,hour,day,week,
--        month,year,decade,century,millennium
CREATE OR REPLACE FUNCTION anon.generalize_tsrange(
  val TIMESTAMP WITHOUT TIME ZONE,
  step TEXT DEFAULT 'decade'
)
RETURNS TSRANGE
AS $$
SELECT tsrange(
    date_trunc(step, val)::TIMESTAMP WITHOUT TIME ZONE,
    date_trunc(step, val)::TIMESTAMP WITHOUT TIME ZONE + ('1 '|| step)::INTERVAL
  );
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-- tstzrange
CREATE OR REPLACE FUNCTION anon.generalize_tstzrange(
  val TIMESTAMP WITH TIME ZONE,
  step TEXT DEFAULT 'decade'
)
RETURNS TSTZRANGE
AS $$
WITH lowerbound AS (
  SELECT date_trunc(step, val)::TIMESTAMP WITH TIME ZONE AS d
)
SELECT tstzrange( d, d + ('1 '|| step)::INTERVAL )
FROM lowerbound
;
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-- daterange — Range of date
CREATE OR REPLACE FUNCTION anon.generalize_daterange(
  val DATE,
  step TEXT DEFAULT 'decade'
)
RETURNS DATERANGE
AS $$
SELECT daterange(
    date_trunc(step, val)::DATE,
    (date_trunc(step, val) + ('1 '|| step)::INTERVAL)::DATE
  );
$$
LANGUAGE SQL IMMUTABLE SECURITY INVOKER;

-------------------------------------------------------------------------------
-- Risk Evaluation
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/k_anonymity.sql

-- This is an attempt to implement various anonymity assement methods.
-- These functions should be used with care.

CREATE OR REPLACE VIEW anon.pg_identifiers AS
WITH const AS (
  SELECT
    '%(quasi|indirect) identifier%'::TEXT AS pattern_indirect_identifier
)
SELECT
  sl.objoid AS attrelid,
  sl.objsubid  AS attnum,
  c.relname,
  a.attname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  sl.label AS col_description,
  lower(sl.label) SIMILAR TO k.pattern_indirect_identifier ESCAPE '#'  AS indirect_identifier,
  100 AS priority -- high priority for the security label syntax
FROM const k,
     pg_catalog.pg_seclabel sl
JOIN pg_catalog.pg_class c ON sl.classoid = c.tableoid AND sl.objoid = c.oid
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND sl.objsubid = a.attnum
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND lower(sl.label) SIMILAR TO k.pattern_indirect_identifier ESCAPE '#'
AND sl.provider = 'anon' -- this is hard-coded in anon.c
;


-- see https://en.wikipedia.org/wiki/K-anonymity
CREATE OR REPLACE FUNCTION  anon.k_anonymity(
  relid REGCLASS
)
RETURNS INTEGER
AS $$
DECLARE
  identifiers TEXT;
  result INTEGER;
BEGIN
  SELECT string_agg(attname,',')
  INTO identifiers
  FROM anon.pg_identifiers
  WHERE relname::REGCLASS = relid;

  IF identifiers IS NULL THEN
    RAISE WARNING 'There is no identifier declared for relation ''%''.',
                  relid::REGCLASS
    USING HINT = 'Use SECURITY LABEL FOR anon ... to declare which columns are '
              || 'indirect identifiers.';
    RETURN NULL;
  END IF;

  EXECUTE format(E'
    SELECT min(c) AS k_anonymity
    FROM (
      SELECT COUNT(*) as c
      FROM %s
      GROUP BY %s
    ) AS k;
  ',
  relid::REGCLASS,
  identifiers
  )
  INTO result;
  RETURN result;
END
$$
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER;

-- TODO : https://en.wikipedia.org/wiki/L-diversity

-- TODO : https://en.wikipedia.org/wiki/T-closeness
