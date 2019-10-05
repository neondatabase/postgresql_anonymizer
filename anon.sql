
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION anon" to load this file. \quit

--
-- Dependencies :
--  * tms_system_rows (should be available with all distributions of postgres)
--  * ddlx ( https://github.com/lacanoid/pgddl )
--

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS @extschema@.config;
CREATE TABLE @extschema@.config (
    param TEXT UNIQUE NOT NULL,
    value TEXT
);

SELECT pg_catalog.pg_extension_config_dump('@extschema@.config','');

COMMENT ON TABLE @extschema@.config IS 'Anonymization and Masking settings';

INSERT INTO @extschema@.config
VALUES
('sourceschema','public'),
('maskschema', 'mask')
;





-------------------------------------------------------------------------------
-- Noise
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.add_noise_on_numeric_column(
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
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.add_noise_on_datetime_column(
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
LANGUAGE plpgsql VOLATILE;

-------------------------------------------------------------------------------
-- Shuffle
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.shuffle_column(
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
LANGUAGE plpgsql VOLATILE;

-------------------------------------------------------------------------------
-- Fake Data
-------------------------------------------------------------------------------

-- Cities, Regions & Countries
DROP TABLE IF EXISTS @extschema@.city;
CREATE TABLE @extschema@.city (
    name TEXT,
    country TEXT,
    subcountry TEXT,
    geonameid TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.city','');

COMMENT ON TABLE @extschema@.city IS 'Cities, Regions & Countries';

-- Companies
DROP TABLE IF EXISTS @extschema@.company;
CREATE TABLE @extschema@.company (
    name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.company','');

-- Email
DROP TABLE IF EXISTS @extschema@.email;
CREATE TABLE @extschema@.email (
    address TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.email','');

-- First names
DROP TABLE IF EXISTS @extschema@.first_name;
CREATE TABLE @extschema@.first_name (
    first_name TEXT,
    male BOOLEAN,
    female BOOLEAN,
    language TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.first_name','');

-- IBAN
DROP TABLE IF EXISTS @extschema@.iban;
CREATE TABLE @extschema@.iban (
    id TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.iban','');

-- Last names
DROP TABLE IF EXISTS @extschema@.last_name;
CREATE TABLE @extschema@.last_name (
    name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.last_name','');

-- SIRET
DROP TABLE IF EXISTS @extschema@.siret;
CREATE TABLE @extschema@.siret (
    siren TEXT,
    nic TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.siret','');

-- ADD NEW TABLE HERE


-------------------------------------------------------------------------------
-- Functions : LOAD / UNLOAD
-------------------------------------------------------------------------------

-- ADD unit tests in tests/sql/load.sql

-- load fake data from a given path
CREATE OR REPLACE FUNCTION @extschema@.load(datapath TEXT)
RETURNS BOOLEAN
AS $func$
DECLARE
  datapath_regexp  TEXT;
  datapath_check TEXT;
BEGIN
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

  -- ADD NEW TABLE HERE
  EXECUTE 'COPY @extschema@.city FROM       '|| quote_literal(datapath ||'/city.csv');
  EXECUTE 'COPY @extschema@.company FROM    '|| quote_literal(datapath ||'/company.csv');
  EXECUTE 'COPY @extschema@.email FROM      '|| quote_literal(datapath ||'/email.csv');
  EXECUTE 'COPY @extschema@.first_name FROM '|| quote_literal(datapath ||'/first_name.csv');
  EXECUTE 'COPY @extschema@.iban FROM       '|| quote_literal(datapath ||'/iban.csv');
  EXECUTE 'COPY @extschema@.last_name FROM  '|| quote_literal(datapath ||'/last_name.csv');
  EXECUTE 'COPY @extschema@.siret FROM      '|| quote_literal(datapath ||'/siret.csv');
  RETURN TRUE;

  EXCEPTION
    WHEN undefined_file THEN
      RAISE WARNING 'The path ''%'' does not exist. Data is not loaded.', datapath;
    RETURN FALSE;
END;
$func$
LANGUAGE PLPGSQL VOLATILE;

-- If no path given, use the default data
CREATE OR REPLACE FUNCTION @extschema@.load()
RETURNS BOOLEAN
AS $$
    WITH conf AS (
        -- find the local extension directory
        SELECT setting AS sharedir
        FROM pg_config
        WHERE name = 'SHAREDIR'
    )
    SELECT @extschema@.load(conf.sharedir || '/extension/anon/')
    FROM conf;
    SELECT TRUE;
$$
LANGUAGE SQL VOLATILE;

-- True, the fake data is already here
CREATE OR REPLACE FUNCTION @extschema@.isloaded()
RETURNS BOOL
AS $$
  SELECT count(*)::INT::BOOL
  FROM (   SELECT 1 FROM @extschema@.siret
     UNION SELECT 1 FROM @extschema@.company
     UNION SELECT 1 FROM @extschema@.last_name
     UNION SELECT 1 FROM @extschema@.city
     UNION SELECT 1 FROM @extschema@.email
     UNION SELECT 1 FROM @extschema@.first_name
     UNION SELECT 1 FROM @extschema@.iban
     LIMIT 1
  ) t
$$
LANGUAGE SQL VOLATILE;

-- remove all fake data
CREATE OR REPLACE FUNCTION @extschema@.unload()
RETURNS BOOLEAN AS $$
    TRUNCATE @extschema@.city;
    TRUNCATE @extschema@.company;
    TRUNCATE @extschema@.email;
    TRUNCATE @extschema@.first_name;
    TRUNCATE @extschema@.iban;
    TRUNCATE @extschema@.last_name;
    TRUNCATE @extschema@.siret;
    SELECT TRUE;
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Random Generic Data
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.random_string(l integer)
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
LANGUAGE SQL VOLATILE;

-- Zip code
CREATE OR REPLACE FUNCTION @extschema@.random_zip()
RETURNS text
AS $$
  SELECT array_to_string(
         array(
                select substr('0123456789',((random()*(10-1)+1)::integer),1)
                from generate_series(1,5)
            ),''
          );
$$
LANGUAGE SQL VOLATILE;


-- date

CREATE OR REPLACE FUNCTION
  @extschema@.random_date_between(
                                  date_start timestamp WITH TIME ZONE,
                                  date_end timestamp WITH TIME ZONE
                                )
RETURNS timestamp WITH TIME ZONE AS $$
    SELECT (random()*(date_end-date_start))::interval+date_start;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_date()
RETURNS timestamp with time zone AS $$
    SELECT @extschema@.random_date_between('01/01/1900'::DATE,now());
$$
LANGUAGE SQL VOLATILE;


-- integer

CREATE OR REPLACE FUNCTION
  @extschema@.random_int_between(int_start INTEGER, int_stop INTEGER)
RETURNS INTEGER AS $$
    SELECT CAST ( random()*(int_stop-int_start)+int_start AS INTEGER );
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_phone(phone_prefix TEXT DEFAULT '0' )
RETURNS TEXT AS $$
    SELECT phone_prefix || CAST(@extschema@.random_int_between(100000000,999999999) AS TEXT) AS "phone";
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- FAKE data
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.fake_first_name()
RETURNS TEXT AS $$
    SELECT first_name
    FROM @extschema@.first_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_last_name()
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.last_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_email()
RETURNS TEXT AS $$
    SELECT address
    FROM @extschema@.email
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_city_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_city()
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.city
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_region_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT subcountry
    FROM @extschema@.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_region()
RETURNS TEXT AS $$
    SELECT subcountry FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_country()
RETURNS TEXT AS $$
    SELECT country FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_company()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.company TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_iban()
RETURNS TEXT AS $$
    SELECT id FROM @extschema@.iban TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_siren()
RETURNS TEXT AS $$
    SELECT siren FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.fake_siret()
RETURNS TEXT AS $$
    SELECT siren||nic FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

--
-- Backward compatibility with version 0.2.1 and earlier
--

CREATE OR REPLACE FUNCTION @extschema@.random_first_name()
RETURNS TEXT AS $$ SELECT @extschema@.fake_first_name() $$
LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION @extschema@.random_last_name()
RETURNS TEXT AS $$ SELECT @extschema@.fake_last_name() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_email()
RETURNS TEXT AS $$ SELECT @extschema@.fake_email() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city_in_country(country_name TEXT)
RETURNS TEXT AS $$ SELECT @extschema@.fake_city_in_country(country_name) $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city()
RETURNS TEXT AS $$ SELECT @extschema@.fake_city() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_region_in_country(country_name TEXT)
RETURNS TEXT AS $$ SELECT @extschema@.fake_region_in_country(country_name) $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_region()
RETURNS TEXT AS $$ SELECT @extschema@.fake_region() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_country()
RETURNS TEXT AS $$ SELECT @extschema@.fake_country() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_company()
RETURNS TEXT AS $$ SELECT @extschema@.fake_company() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_iban()
RETURNS TEXT AS $$ SELECT @extschema@.fake_iban() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_siren()
RETURNS TEXT AS $$ SELECT @extschema@.fake_siren() $$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_siret()
RETURNS TEXT AS $$ SELECT @extschema@.fake_siret() $$
LANGUAGE SQL VOLATILE;



-------------------------------------------------------------------------------
-- Partial Scrambling
-------------------------------------------------------------------------------

--
-- partial('abcdefgh',1,'xxxx',3) will return 'axxxxfgh';
--
CREATE OR REPLACE FUNCTION @extschema@.partial(
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
LANGUAGE SQL IMMUTABLE;

--
-- email('daamien@gmail.com') will becomme 'da******@gm******.com'
--
CREATE OR REPLACE FUNCTION @extschema@.partial_email(ov TEXT)
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
LANGUAGE SQL IMMUTABLE;


-------------------------------------------------------------------------------
-- Masking Rules Management
-- This is the common metadata used by the 3 main features :
-- anonymize(), dump() and dynamic masking engine
-------------------------------------------------------------------------------

-- List of all the masked columns
CREATE OR REPLACE VIEW @extschema@.pg_masking_rules AS
WITH const AS (
  SELECT
    '%MASKED +WITH +FUNCTION +#"%#(%#)#"%'::TEXT
      AS pattern_mask_column_function,
    '%MASKED +WITH +CONSTANT +#"%#(%#)#"%'::TEXT
      AS pattern_mask_column_constant
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
              from k.pattern_mask_column_constant for '#')
    AS masking_constant,
  0 AS priority --low priority for the comment syntax
FROM const k,
     pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (   pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
    OR  pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_constant ESCAPE '#'
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
  substring(sl.label from k.pattern_mask_column_constant for '#')  AS masking_constant,
  100 AS priority -- high priority for the security label syntax
FROM const k,
     pg_catalog.pg_seclabel sl
JOIN pg_catalog.pg_class c ON sl.classoid = c.tableoid AND sl.objoid = c.oid
JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND sl.objsubid = a.attnum
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (   sl.label SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
    OR  sl.label SIMILAR TO k.pattern_mask_column_constant ESCAPE '#'
    )
AND sl.provider = 'anon' -- this is hard-coded in anon.c
),
rules_from_all AS (
SELECT * FROM rules_from_comments
UNION
SELECT * FROM rules_from_seclabels
)
-- DISTINCT will keep just the 1st rule for each column based on priority,
SELECT DISTINCT ON (attrelid, attnum) *
FROM rules_from_all
ORDER BY attrelid, attnum, priority DESC
;

-- Compatibility with version 0.3 and earlier
CREATE OR REPLACE VIEW @extschema@.pg_masks AS
SELECT * FROM @extschema@.pg_masking_rules
;


-- name of the source schema
CREATE OR REPLACE FUNCTION @extschema@.source_schema()
RETURNS TEXT AS
$$ SELECT value FROM @extschema@.config WHERE param='sourceschema' $$
LANGUAGE SQL STABLE;

-- name of the masking schema
CREATE OR REPLACE FUNCTION @extschema@.mask_schema()
RETURNS TEXT AS
$$
SELECT value
FROM @extschema@.config
WHERE param='maskschema'
;
$$
LANGUAGE SQL STABLE;

-------------------------------------------------------------------------------
-- In-Place Anonymization
-------------------------------------------------------------------------------

-- Replace masked data in a column
CREATE OR REPLACE FUNCTION @extschema@.anonymize_column(
                                                        tablename REGCLASS,
                                                        colname NAME
                                                      )
RETURNS BOOLEAN AS
$$
DECLARE
  mf TEXT;
  mf_is_a_faking_function BOOLEAN;
BEGIN
  SELECT masking_function INTO mf
  FROM @extschema@.pg_masking_rules
  WHERE attrelid = tablename::OID
  AND attname = colname;

  IF mf IS NULL THEN
  RAISE WARNING 'There is no masking rule for column % in table %', colname, tablename;
  RETURN FALSE;
  END IF;

  SELECT mf LIKE 'anon.fake_%' INTO mf_is_a_faking_function;
  IF mf_is_a_faking_function AND not anon.isloaded() THEN
    RAISE NOTICE 'The faking data is not loaded. You probably need to run ''SELECT @extschema@.load()'' ';
  END IF;

  RAISE DEBUG 'Anonymize %.% with %', tablename,colname, mf;
  EXECUTE format('UPDATE %s SET %I = %s', tablename,colname, mf);

  RETURN TRUE;
END;
$$
LANGUAGE plpgsql VOLATILE;


-- Replace masked data in a table
CREATE OR REPLACE FUNCTION @extschema@.anonymize_table(tablename REGCLASS)
RETURNS BOOLEAN AS
$func$
  SELECT @extschema@.anonymize_column(tablename,attname)
  FROM @extschema@.pg_masking_rules
  WHERE attrelid::regclass=tablename;
$func$
LANGUAGE SQL VOLATILE;


-- Walk through all masked columns and permanently apply the mask
CREATE OR REPLACE FUNCTION @extschema@.anonymize_database()
RETURNS BOOLEAN AS
$func$
  SELECT SUM(anon.anonymize_column(attrelid::REGCLASS,attname)::INT) = COUNT(attrelid)
  FROM anon.pg_masking_rules;
$func$
LANGUAGE SQL VOLATILE;

-- Backward compatibility with version 0.2
CREATE OR REPLACE FUNCTION @extschema@.static_substitution()
RETURNS BOOLEAN AS
$func$
  SELECT @extschema@.anonymize_database();
$func$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Dynamic Masking
-------------------------------------------------------------------------------

-- ADD TEST IN FILES:
--   * tests/sql/masking.sql
--   * tests/sql/masking_PG11+.sql
--   * tests/sql/hasmask.sql

-- True if the role is masked
CREATE OR REPLACE FUNCTION @extschema@.hasmask(role REGROLE)
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
LANGUAGE SQL STABLE
;

-- DEPRECATED : use directly `hasmask(oid::REGROLE)` instead
-- Adds a `hasmask` column to the pg_roles catalog
CREATE OR REPLACE VIEW @extschema@.pg_masked_roles AS
SELECT r.*, @extschema@.hasmask(r.oid::REGROLE)
FROM pg_catalog.pg_roles r
;

-- Display all columns of the relation with the masking function (if any)
CREATE OR REPLACE FUNCTION @extschema@.mask_columns(source_relid OID)
RETURNS TABLE (
    attname NAME,
    masking_function TEXT,
    format_type TEXT
) AS
$$
SELECT
  a.attname::NAME, -- explicit cast for PG 9.6
  m.masking_function,
  m.format_type
FROM pg_attribute a
LEFT JOIN  @extschema@.pg_masking_rules m
        ON m.attrelid = a.attrelid
        AND m.attname = a.attname
WHERE  a.attrelid = source_relid
AND    a.attnum > 0 -- exclude ctid, cmin, cmax
AND    NOT a.attisdropped
ORDER BY a.attnum
;
$$
LANGUAGE SQL VOLATILE;

-- build a masked view for each table
-- /!\ Disable the Event Trigger before calling this :-)
-- We can't use the namespace oids because the mask schema may not be present
CREATE OR REPLACE FUNCTION  @extschema@.mask_create()
RETURNS SETOF VOID AS
$$
BEGIN
  -- Walk through all tables in the source schema
  PERFORM @extschema@.mask_create_view(oid)
  FROM pg_class
  WHERE relnamespace=@extschema@.sourceschema()::regnamespace
  AND relkind = 'r' -- relations only
  ;
END
$$
LANGUAGE plpgsql VOLATILE;


-- get the "select filters" that will mask the real data of a table
CREATE OR REPLACE FUNCTION @extschema@.mask_filters( relid OID )
RETURNS TEXT AS
$$
DECLARE
    m RECORD;
    expression TEXT;
    comma TEXT;
BEGIN
    expression := '';
    comma := '';
    FOR m IN SELECT * FROM @extschema@.mask_columns(relid)
    LOOP
        expression := expression || comma;
        IF m.masking_function IS NULL THEN
            -- No mask found
            expression := expression || quote_ident(m.attname);
        ELSE
            -- Call mask instead of column
            -- the masking function is casted into the column type
            expression := expression || format('CAST(%s AS %s) AS %s',
                                                m.masking_function,
                                                m.format_type,
                                                quote_ident(m.attname)
                                              );
        END IF;
        comma := ',';
    END LOOP;
  RETURN expression;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Build a masked view for a table
CREATE OR REPLACE FUNCTION @extschema@.mask_create_view( relid OID )
RETURNS BOOLEAN AS
$$
BEGIN
  EXECUTE format('CREATE OR REPLACE VIEW "%s".%s AS SELECT %s FROM %s',
                                  @extschema@.mask_schema(),
                                  relid::REGCLASS,
                                  @extschema@.mask_filters(relid),
                                  relid::REGCLASS);
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Remove a masked view for a given table
CREATE OR REPLACE FUNCTION @extschema@.mask_drop_view( relid OID )
RETURNS BOOLEAN AS
$$
BEGIN
  EXECUTE format('DROP VIEW "%s".%s;', @extschema@.mask_schema(),
                                         relid::REGCLASS
  );
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Activate the masking engine
CREATE OR REPLACE FUNCTION @extschema@.start_dynamic_masking(
                                                sourceschema TEXT DEFAULT 'public',
                                                maskschema TEXT DEFAULT 'mask',
                                                autoload BOOLEAN DEFAULT TRUE
                                                )
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN
  SELECT @extschema@.isloaded() AS loaded INTO r;
  IF NOT autoload THEN
    RAISE DEBUG 'Autoload is disabled.';
  ELSEIF r.loaded THEN
    RAISE DEBUG 'Anon data is already loaded.';
  ELSE
    PERFORM @extschema@.load();
  END IF;

  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', maskschema);
  EXECUTE format('UPDATE @extschema@.config SET value=''%s'' WHERE param=''sourceschema'';', sourceschema);
  EXECUTE format('UPDATE @extschema@.config SET value=''%s'' WHERE param=''maskschema'';', maskschema);

  PERFORM @extschema@.mask_update();

  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Backward compatibility with version 0.2
CREATE OR REPLACE FUNCTION @extschema@.mask_init(
                                          sourceschema TEXT DEFAULT 'public',
                                          maskschema TEXT DEFAULT 'mask',
                                          autoload BOOLEAN DEFAULT TRUE
                                          )
RETURNS BOOLEAN AS
$$
SELECT @extschema@.start_dynamic_masking(sourceschema,maskschema,autoload);
$$
LANGUAGE SQL VOLATILE;

-- this is opposite of start_dynamic_masking()
CREATE OR REPLACE FUNCTION @extschema@.stop_dynamic_masking()
RETURNS BOOLEAN AS
$$
BEGIN
  PERFORM @extschema@.mask_disable();

  -- Walk through all tables in the source schema and drop the masking view
  PERFORM @extschema@.mask_drop_view(oid)
  FROM pg_class
  WHERE relnamespace=@extschema@.source_schema()::regnamespace
  AND relkind = 'r' -- relations only
  ;

  -- Walk through all masked roles and remove their masl
  PERFORM @extschema@.unmask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE @extschema@.hasmask(oid::REGROLE);

  -- Erase the config
  DELETE FROM @extschema@.config WHERE param='sourceschema';
  DELETE FROM @extschema@.config WHERE param='maskschema';

  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;



-- This is run after all DDL query
CREATE OR REPLACE FUNCTION @extschema@.mask_trigger()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Functions cannot return EVENT_TRIGGER,
-- we're forced to write a plpgsql function
BEGIN
  PERFORM @extschema@.mask_update();
END
$$
LANGUAGE plpgsql;


-- Mask a specific role
CREATE OR REPLACE FUNCTION @extschema@.mask_role(maskedrole REGROLE)
RETURNS BOOLEAN AS
$$
DECLARE
  sourceschema REGNAMESPACE;
  maskschema REGNAMESPACE;
BEGIN
  SELECT @extschema@.source_schema()::REGNAMESPACE INTO sourceschema;
  SELECT @extschema@.mask_schema()::REGNAMESPACE INTO maskschema;
  RAISE DEBUG 'Mask role % (% -> %)', maskedrole, sourceschema, maskschema;
  EXECUTE format('REVOKE ALL ON SCHEMA %s FROM %s', sourceschema, maskedrole);
  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', '@extschema@', maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s', '@extschema@', maskedrole);
  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', maskschema, maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s', maskschema, maskedrole);
  EXECUTE format('ALTER ROLE %s SET search_path TO %s,%s;', maskedrole, maskschema,sourceschema);
  RETURN TRUE;
END
$$
LANGUAGE plpgsql;

-- Remove (partially) the mask of a specific role
CREATE OR REPLACE FUNCTION @extschema@.unmask_role(maskedrole REGROLE)
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
LANGUAGE plpgsql;


-- load the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_enable()
RETURNS BOOLEAN AS
$$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_event_trigger WHERE evtname='@extschema@_mask_update'
  )
  THEN
    CREATE EVENT TRIGGER @extschema@_mask_update ON ddl_command_end
    EXECUTE PROCEDURE @extschema@.mask_trigger();
  ELSE
    RAISE DEBUG 'event trigger "@extschema@_mask_update" already exists: skipping';
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- unload the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_disable()
RETURNS BOOLEAN AS
$$
BEGIN
  IF EXISTS (
    SELECT FROM pg_event_trigger WHERE evtname='@extschema@_mask_update'
  )
  THEN
    DROP EVENT TRIGGER IF EXISTS @extschema@_mask_update;
  ELSE
    RAISE DEBUG 'event trigger "@extschema@_mask_update" does not exist: skipping';
  RETURN FALSE;
  END IF;
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Rebuild the dynamic masking views and masked roles from scratch
CREATE OR REPLACE FUNCTION @extschema@.mask_update()
RETURNS BOOLEAN AS
$$
  -- This DDL EVENT TRIGGER will launch new DDL statements
  -- therefor we have disable the EVENT TRIGGER first
  -- in order to avoid an infinite triggering loop :-)
  SELECT @extschema@.mask_disable();

  -- Walk through all tables in the source schema
  -- and build a dynamic masking view
  SELECT @extschema@.mask_create_view(oid)
  FROM pg_class
  WHERE relnamespace=@extschema@.source_schema()::regnamespace
  AND relkind = 'r' -- relations only
  ;

  -- Walk through all masked roles and apply the restrictions
  SELECT @extschema@.mask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE @extschema@.hasmask(oid::REGROLE);

  -- Restore the mighty DDL EVENT TRIGGER
  SELECT @extschema@.mask_enable();
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Anonymous Dumps
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.dump_ddl()
RETURNS TABLE (
    ddl TEXT
) AS
$$
    SELECT ddlx_create(oid)
    FROM pg_class
    WHERE relkind != 't' -- exclude the TOAST objeema@.mask_rolests
    AND relnamespace IN (
      SELECT oid
      FROM pg_namespace
      WHERE nspname NOT LIKE 'pg_%'
      AND nspname NOT IN  ( 'information_schema' ,
                            '@extschema@' ,
                            @extschema@.mask_schema()
                          )
    )
  -- drop [S]equences before [t]ables
  ORDER BY  array_position(ARRAY['S','t'], relkind::TEXT),
            oid::regclass
    ;
$$
LANGUAGE SQL;

-- generate the "COPY ... FROM STDIN" statement for a table
CREATE OR REPLACE FUNCTION @extschema@.get_copy_statement(relid OID)
RETURNS TEXT AS
$$
DECLARE
  copy_statement TEXT;
  val TEXT;
  rec RECORD;
BEGIN
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
LANGUAGE plpgsql VOLATILE;


-- export content of all the tables as COPY statements
CREATE OR REPLACE FUNCTION @extschema@.dump_data()
RETURNS TABLE (
    data TEXT
) AS
$$
  SELECT @extschema@.get_copy_statement(relid)
  FROM pg_stat_user_tables
  WHERE schemaname NOT IN ( '@extschema@' , @extschema@.mask_schema() )
  ORDER BY  relid::regclass -- sort by name to force the dump order
$$
LANGUAGE SQL;

-- export the database schema + anonymized data
CREATE OR REPLACE FUNCTION @extschema@.dump()
RETURNS TABLE (
  dump TEXT
) AS
$$
    SELECT @extschema@.dump_ddl()
    UNION ALL -- ALL is required to maintain the lines order as appended
    SELECT @extschema@.dump_data()
$$
LANGUAGE SQL;




-------------------------------------------------------------------------------
-- Scanning
-------------------------------------------------------------------------------

CREATE TABLE @extschema@.suggest(
    attname TEXT,
    suggested_mask TEXT
);

INSERT INTO @extschema@.suggest
VALUES
('firstname','random_first_name()'),
('first_name','random_first_name()'),
('given_name','random_first_name()'),
('prenom','random_first_name()'),
('creditcard','FIXME'),
('credit_card','FIXME'),
('CB','FIXME'),
('carte_bancaire','FIXME'),
('cartebancaire','FIXME')
;

CREATE OR REPLACE VIEW @extschema@.scan AS
SELECT
  a.attrelid,
  a.attname,
  s.suggested_mask,
  pg_catalog.col_description(a.attrelid, a.attnum)
FROM pg_catalog.pg_attribute a
JOIN @extschema@.suggest s ON  lower(a.attname) = s.attname
;
