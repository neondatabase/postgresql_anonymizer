
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION anon" to load this file. \quit

-- the tms_system_rows extension should be available with all distributions of postgres
--CREATE EXTENSION IF NOT EXISTS tsm_system_rows;

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS @extschema@.config;
CREATE UNLOGGED TABLE @extschema@.config (
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
-- Fake Data
-------------------------------------------------------------------------------

-- Cities, Regions & Countries
DROP TABLE IF EXISTS @extschema@.city;
CREATE UNLOGGED TABLE @extschema@.city (
    name TEXT,
    country TEXT,
    subcountry TEXT,
    geonameid TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.city','');

COMMENT ON TABLE @extschema@.city IS 'Cities, Regions & Countries';

-- Companies
DROP TABLE IF EXISTS @extschema@.company;
CREATE UNLOGGED TABLE @extschema@.company (
    name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.company','');

-- Email
DROP TABLE IF EXISTS @extschema@.email;
CREATE UNLOGGED TABLE @extschema@.email (
    address TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.email','');

-- First names
DROP TABLE IF EXISTS @extschema@.first_name;
CREATE UNLOGGED TABLE @extschema@.first_name (
    first_name TEXT,
    male BOOLEAN,
    female BOOLEAN,
    language TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.first_name','');

-- IBAN
DROP TABLE IF EXISTS iban;
CREATE UNLOGGED TABLE iban (
    id TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.iban','');

-- Last names
DROP TABLE IF EXISTS @extschema@.last_name;
CREATE UNLOGGED TABLE @extschema@.last_name (
    name TEXT
);
SELECT pg_catalog.pg_extension_config_dump('@extschema@.last_name','');

-- SIRET
DROP TABLE IF EXISTS @extschema@.siret;
CREATE UNLOGGED TABLE @extschema@.siret (
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
BEGIN
    -- ADD NEW TABLE HERE
    EXECUTE format('COPY @extschema@.city FROM ''%s/city.csv''',datapath);
    EXECUTE format('COPY @extschema@.company FROM ''%s/company.csv''',datapath);
    EXECUTE format('COPY @extschema@.email FROM ''%s/email.csv''',datapath);
    EXECUTE format('COPY @extschema@.first_name FROM ''%s/first_name.csv''',datapath);
    EXECUTE format('COPY @extschema@.iban FROM ''%s/iban.csv''',datapath);
    EXECUTE format('COPY @extschema@.last_name FROM ''%s/last_name.csv''',datapath);
    EXECUTE format('COPY @extschema@.siret FROM ''%s/siret.csv''',datapath);
    RETURN TRUE;
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
        select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',((random()*(36-1)+1)::integer),1)
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

CREATE OR REPLACE FUNCTION @extschema@.random_date_between(date_start timestamp WITH TIME ZONE, date_end timestamp WITH TIME ZONE)
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

CREATE OR REPLACE FUNCTION @extschema@.random_int_between(int_start INTEGER, int_stop INTEGER)
RETURNS INTEGER AS $$
    SELECT CAST ( random()*(int_stop-int_start)+int_start AS INTEGER );
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Random Personal data : First Name, Last Name, etc.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.random_first_name()
RETURNS TEXT AS $$
    SELECT first_name
    FROM @extschema@.first_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_last_name()
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.last_name
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_email()
RETURNS TEXT AS $$
    SELECT address
    FROM @extschema@.email
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city()
RETURNS TEXT AS $$
    SELECT name
    FROM @extschema@.city
    TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_region_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT subcountry
    FROM @extschema@.city
    WHERE country=country_name
    ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_region()
RETURNS TEXT AS $$
    SELECT subcountry FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_country()
RETURNS TEXT AS $$
    SELECT country FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION @extschema@.random_phone(phone_prefix TEXT DEFAULT '0' )
RETURNS TEXT AS $$
    SELECT phone_prefix || CAST(@extschema@.random_int_between(100000000,999999999) AS TEXT) AS "phone";
$$
LANGUAGE SQL VOLATILE;


-------------------------------------------------------------------------------
-- Random Commercial Data : Company Names, SIRET, IBAN, etc.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.random_company()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.company TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_iban()
RETURNS TEXT AS $$
    SELECT id FROM @extschema@.iban TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_siren()
RETURNS TEXT AS $$
    SELECT siren FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_siret()
RETURNS TEXT AS $$
    SELECT siren||nic FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;


-------------------------------------------------------------------------------
-- Partial Scrambling
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.partial(ov TEXT, prefix INT, padding TEXT, suffix INT)
RETURNS TEXT AS $$
  SELECT substring(ov FROM 1 FOR prefix)
      || padding
      || substring(ov FROM (length(ov)-suffix+1) FOR suffix);
$$
LANGUAGE SQL;


CREATE OR REPLACE FUNCTION @extschema@.partial_email(ov TEXT)
RETURNS TEXT AS $$
-- This is an oversimplistic way to scramble an email address
--
-- The main goal is to avoid any complex regexp by splitting
-- the job into simpler tasks
--
-- Example :  'daamien@gmail.com' will becomme 'da******@gm******.com'
--
  SELECT substring(regexp_replace(ov, '@.*', '') FROM 1 FOR 2) -- da
      || '******'
      || '@'
      || substring(regexp_replace(ov, '.*@', '') FROM 1 FOR 2) -- gm
      || '******'
      || '.'
      || regexp_replace(ov, '.*\.', '') -- com
  ;
$$
LANGUAGE SQL;

-------------------------------------------------------------------------------
-- Masking
-------------------------------------------------------------------------------


-- List of all the masked columns
CREATE OR REPLACE VIEW @extschema@.pg_masks AS
WITH const AS (
    SELECT
        '%MASKED +WITH +FUNCTION +#"%#(%#)#"%' AS pattern_mask_column_function,
        '%MASKED +WITH +CONSTANT +#"%#(%#)#"%' AS pattern_mask_column_constant
)
SELECT
  a.attrelid,
  a.attname,
  c.relname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  pg_catalog.col_description(a.attrelid, a.attnum),
  substring(pg_catalog.col_description(a.attrelid, a.attnum) from k.pattern_mask_column_function for '#')  AS func,
  substring(pg_catalog.col_description(a.attrelid, a.attnum) from k.pattern_mask_column_function for '#')  AS masking_constant
FROM const k,
     pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
--AND pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO '%MASKED +WITH +\( *FUNCTION *= *(%) *\)%'
AND ( 
    pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO '%MASKED +WITH +FUNCTION +#"%#(%#)#"%' ESCAPE '#'
--OR  pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO '%MASKED +WITH +CONSTANT +#"%#(%#)#"%' ESCAPE '#' 
)
;

-- Adds a `hasmask` column to the pg_roles catalog
-- True if the role is masked, else False
CREATE OR REPLACE VIEW @extschema@.pg_masked_roles AS
SELECT r.*,
    COALESCE(shobj_description(r.oid,'pg_authid') SIMILAR TO '%MASKED%',false) AS hasmask
FROM pg_roles r
;

-- Walk through all masked columns and permanently apply the mask
-- This is not makeing function, but it relies on the masking infra
CREATE OR REPLACE FUNCTION @extschema@.static_substitution()
RETURNS setof void
AS $$
DECLARE
    col RECORD;
BEGIN
  RAISE DEBUG 'ANONYMIZE ALL THE THINGS \o/';
  FOR col IN
    SELECT * FROM @extschema@.pg_masks
  LOOP
    RAISE DEBUG 'Anonymize %.% with %', col.relname,col.attname, col.func;
    EXECUTE format('UPDATE "%s" SET "%s" = %s', col.relname,col.attname, col.func);
  END LOOP;
END;
$$
LANGUAGE plpgsql;

-- True if the role is masked
CREATE OR REPLACE FUNCTION @extschema@.hasmask(role TEXT)
RETURNS BOOLEAN AS
$$
-- FIXME : CHECK quote_ident
SELECT hasmask
FROM @extschema@.pg_masked_roles
WHERE rolname = quote_ident(role);
$$
LANGUAGE SQL;

-- Extend the columns catalof with a 'func' field
CREATE OR REPLACE FUNCTION @extschema@.mask_columns(sourcetable TEXT,sourceschema TEXT DEFAULT 'public')
RETURNS TABLE (
    attname TEXT,
    func TEXT
) AS
$$
SELECT
    c.column_name,
    m.func
FROM information_schema.columns c
LEFT JOIN @extschema@.pg_masks m ON m.attname = c.column_name
WHERE table_name=sourcetable
and table_schema=quote_ident(sourceschema)
-- FIXME : FILTER schema_name on anon.pg_mask too
;
$$
LANGUAGE SQL;

-- build a masked view for each table
-- /!\ Disable the Event Trigger before calling this :-)
CREATE OR REPLACE FUNCTION  @extschema@.mask_create(sourceschema TEXT, maskschema TEXT)
RETURNS SETOF VOID AS
$$
DECLARE
    t RECORD;
BEGIN
  -- Be sure that the target schema is here
  IF NOT EXISTS (
    SELECT
    FROM information_schema.schemata
    WHERE schema_name = maskschema
  )
  THEN
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I',maskschema);
  END IF;

  -- Walk through all tables in the source schema
  FOR  t IN SELECT * FROM pg_tables WHERE schemaname = quote_ident(sourceschema)
  LOOP
    PERFORM @extschema@.mask_create_view(t.tablename,sourceschema,maskschema);
  END LOOP;
END
$$
LANGUAGE plpgsql;

-- Build a masked view for a table
CREATE OR REPLACE FUNCTION @extschema@.mask_create_view(sourcetable TEXT, sourceschema TEXT DEFAULT 'public', maskschema TEXT DEFAULT 'mask')
RETURNS SETOF VOID AS
$$
DECLARE
    m RECORD;
    expression TEXT;
    comma TEXT;
    --func TEXT;
BEGIN
    expression := '';
    comma := '';
    FOR m IN SELECT * FROM @extschema@.mask_columns(sourcetable)
    LOOP
        expression := expression || comma;
        IF m.func IS NULL THEN
            -- No mask found
            expression := expression || quote_ident(m.attname);
        ELSE
            -- TODO : Insert original value in the masking function
            --func := replace(m.func, '(' , '(' || quote_ident(m.attname) || ',');
            -- Call mask instead of column
            expression := expression || m.func || ' AS ' || quote_ident(m.attname);
        END IF;
        comma := ',';
    END LOOP;
    EXECUTE format('CREATE OR REPLACE VIEW %I.%I AS SELECT %s FROM %I', maskschema, sourcetable, expression, sourcetable);
END
$$
LANGUAGE plpgsql;

-- Activate the masking engine
CREATE OR REPLACE FUNCTION @extschema@.mask_init()
RETURNS SETOF VOID AS
$$
DECLARE
    r RECORD;
BEGIN
  SELECT @extschema@.isloaded() AS loaded INTO r;
  IF r.loaded THEN
    RAISE DEBUG 'Anon data is already loaded.';
  ELSE
    PERFORM @extschema@.load();
  END IF;

  PERFORM @extschema@.mask_update();
END
$$
LANGUAGE plpgsql;

-- FIXME
-- CREATE OR REPLACE FUNCTION mask_destroy()

-- This is run after all DDL query
CREATE OR REPLACE FUNCTION @extschema@.mask_trigger()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Functions cannot return EVENT_TRIGGER, we're forced to write a plpgsql function
BEGIN
  PERFORM @extschema@.mask_update();
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION @extschema@.mask_update()
RETURNS SETOF VOID AS
$$
DECLARE
    sourceschema TEXT;
    maskschema TEXT;
BEGIN
    SELECT value INTO sourceschema FROM @extschema@.config WHERE param='sourceschema';
    SELECT value INTO maskschema FROM @extschema@.config WHERE param='maskschema';
    PERFORM @extschema@.mask_disable();
    PERFORM @extschema@.mask_create(sourceschema,maskschema);
    PERFORM @extschema@.mask_roles(sourceschema,maskschema);
    PERFORM @extschema@.mask_enable();
END
$$
LANGUAGE plpgsql;

-- Mask all roles
CREATE OR REPLACE FUNCTION @extschema@.mask_roles(sourceschema TEXT, maskschema TEXT)
RETURNS SETOF VOID AS
$$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM @extschema@.pg_masked_roles WHERE hasmask
    LOOP
        PERFORM @extschema@.mask_role(r.rolname,sourceschema,maskschema);
    END LOOP;
END
$$
LANGUAGE plpgsql;

-- Mask a specific role
CREATE OR REPLACE FUNCTION @extschema@.mask_role(maskedrole TEXT, sourceschema TEXT, maskschema TEXT)
RETURNS SETOF VOID AS
$$
BEGIN
    RAISE DEBUG 'Mask role % (% -> %)', maskedrole, sourceschema, maskschema;
    EXECUTE format('REVOKE ALL ON SCHEMA %I FROM %I', sourceschema, maskedrole);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', 'anon', maskedrole);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', 'anon', maskedrole);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', maskschema, maskedrole);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', maskschema, maskedrole);
    EXECUTE format('ALTER ROLE %I SET search_path TO %I,%I;', maskedrole, maskschema,sourceschema);
END
$$
LANGUAGE plpgsql;

-- load the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_enable()
RETURNS SETOF VOID AS
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
  END IF;
END
$$
LANGUAGE plpgsql;

-- unload the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_disable()
RETURNS SETOF VOID AS
$$
BEGIN
  IF EXISTS (
    SELECT FROM pg_event_trigger WHERE evtname='@extschema@_mask_update'
  )
  THEN
    DROP EVENT TRIGGER IF EXISTS @extschema@_mask_update;
  ELSE
    RAISE DEBUG 'event trigger "@extschema@_mask_update" does not exist: skipping';
  END IF;
END
$$
LANGUAGE plpgsql;


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
