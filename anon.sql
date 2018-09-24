
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION anon" to load this file. \quit

-- the tms_system_rows extension should be available with all distributions of postgres
--CREATE EXTENSION IF NOT EXISTS tsm_system_rows;


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


--
-- Functions : LOAD / UNLOAD
--

-- load fake data from a given path
CREATE OR REPLACE FUNCTION @extschema@.load(datapath TEXT)
RETURNS void AS $$
BEGIN
	-- ADD NEW TABLE HERE
	EXECUTE format('COPY @extschema@.city FROM ''%s/city.csv''',datapath);
    EXECUTE format('COPY @extschema@.company FROM ''%s/company.csv''',datapath);
    EXECUTE format('COPY @extschema@.email FROM ''%s/email.csv''',datapath);
    EXECUTE format('COPY @extschema@.first_name FROM ''%s/first_name.csv''',datapath);
    EXECUTE format('COPY @extschema@.iban FROM ''%s/iban.csv''',datapath);
    EXECUTE format('COPY @extschema@.last_name FROM ''%s/last_name.csv''',datapath);
    EXECUTE format('COPY @extschema@.siret FROM ''%s/siret.csv''',datapath);
    RETURN;
END;
$$
LANGUAGE PLPGSQL VOLATILE;

-- If no path given, use the default data
CREATE OR REPLACE FUNCTION @extschema@.load()
RETURNS void AS $$
	WITH conf AS (
		SELECT setting AS sharedir
		FROM pg_config
		WHERE name = 'SHAREDIR'
	)
	SELECT @extschema@.load(conf.sharedir || '/extension/anon/')
	FROM conf;
$$
LANGUAGE SQL VOLATILE;

-- remove all fake data
CREATE OR REPLACE FUNCTION @extschema@.unload()
RETURNS void AS $$
    TRUNCATE @extschema@.city;
    TRUNCATE @extschema@.company;
    TRUNCATE @extschema@.email;
	TRUNCATE @extschema@.first_name;
    TRUNCATE @extschema@.iban;
	TRUNCATE @extschema@.last_name;
    TRUNCATE @extschema@.siret;
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Functions : Generic Types
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.random_string(l integer)
RETURNS text AS $$ SELECT array_to_string(
			array(
				select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',((random()*(36-1)+1)::integer),1)
				from generate_series(1,l)
			),''
		  ); $$
LANGUAGE SQL VOLATILE;

-- Zip code
CREATE OR REPLACE FUNCTION @extschema@.random_zip()
RETURNS text AS $$ SELECT array_to_string(
            array(
                select substr('0123456789',((random()*(10-1)+1)::integer),1)
                from generate_series(1,5)
            ),''
          ); $$
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

--
-- Personal data : First Name, Last Name, etc.
--

CREATE OR REPLACE FUNCTION @extschema@.random_first_name()
RETURNS TEXT AS $$
	SELECT first_name FROM @extschema@.first_name TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_last_name()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_email()
RETURNS TEXT AS $$
	SELECT address FROM @extschema@.email TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city_in_country(country_name TEXT)
RETURNS TEXT AS $$
	SELECT name FROM @extschema@.city WHERE country=country_name ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_city()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION @extschema@.random_region_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT subcountry FROM @extschema@.city WHERE country=country_name ORDER BY random() LIMIT 1;
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


CREATE OR REPLACE FUNCTION @extschema@.random_phone( phone_prefix TEXT DEFAULT '0' )
RETURNS TEXT AS $$
	SELECT phone_prefix || CAST(@extschema@.random_int_between(100000000,999999999) AS TEXT) AS "phone";
$$
LANGUAGE SQL VOLATILE;


--
-- Company data : Name, SIRET, IBAN, etc.
--

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
-- Masking
-------------------------------------------------------------------------------

-- List of all the masked columns
CREATE OR REPLACE VIEW @extschema@.pg_masks AS
SELECT
  a.attrelid,
  a.attname,
  c.relname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  pg_catalog.col_description(a.attrelid, a.attnum),
  substring(pg_catalog.col_description(a.attrelid, a.attnum) from '%MASKED +WITH +#( *FUNCTION *= *#"%#(%#)#" *#)%' for '#')  AS func
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
--AND pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO '%MASKED +WITH +\( *FUNCTION *= *(%) *\)%'
AND pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO '%MASKED +WITH +#( *FUNCTION *= *#"%#(%#)#" *#)%' ESCAPE '#'
;

-- Add a `hasmask` column to the pg_roles catalog
-- True if the role is masked, else False
CREATE OR REPLACE VIEW @extschema@.pg_masked_roles AS
SELECT r.*,
	COALESCE(shobj_description(r.oid,'pg_authid') SIMILAR TO '% *MASK %',false) AS hasmask
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
    RAISE DEBUG 'Anon %.% with %', col.relname,col.attname, col.func;
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
LEFT JOIN anon.mask m ON m.attname = c.column_name
WHERE table_name=sourcetable
and table_schema=quote_ident(sourceschema)
-- FIXME : FILTER schema_name on anon.pg_mask too
;
$$
LANGUAGE SQL;

-- build a masked view for each table
-- /!\ Disable the Event Trigger before calling this :-)
CREATE OR REPLACE FUNCTION  @extschema@.mask_create(sourceschema TEXT DEFAULT 'public', maskschema TEXT DEFAULT 'mask')
RETURNS SETOF VOID AS
$$
DECLARE
	t RECORD;
BEGIN
	FOR  t IN SELECT * FROM pg_tables WHERE schemaname = 'public'
	LOOP
		EXECUTE format('SELECT @extschema@.mask_create_view(%L,%L);',t.tablename,maskschema);
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
-- For now, init = update
BEGIN
	PERFORM @extschema@.mask_disable();
	PERFORM @extschema@.mask_create();
	PERFORM @extschema@.mask_enable();
END
$$
LANGUAGE plpgsql;

-- FIXME
-- CREATE OR REPLACE FUNCTION mask_destroy()

-- This is run after all DDL query
CREATE OR REPLACE FUNCTION mask_update()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Functions cannot return EVENT_TRIGGER, we're forced to write a plpgsql function
-- For now, create = update
BEGIN
	PERFORM @extschema@.mask_disable();
	PERFORM @extschema@.mask_create();
	PERFORM @extschema@.mask_enable();
END
$$
LANGUAGE plpgsql;

-- load the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_enable()
RETURNS SETOF VOID AS
$$
CREATE EVENT TRIGGER @extschema@_mask_update ON ddl_command_end
EXECUTE PROCEDURE @extschema@.mask_update();
$$
LANGUAGE SQL;

-- unload the event trigger
CREATE OR REPLACE FUNCTION @extschema@.mask_disable()
RETURNS SETOF VOID AS
$$
DROP EVENT TRIGGER @extschema@_mask_update;
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
JOIN anon.suggest s ON  lower(a.attname) = s.attname
;
