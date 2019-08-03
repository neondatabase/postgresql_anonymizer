
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION anon" to load this file. \quit

-- the tms_system_rows extension should be available with all distributions of postgres
--CREATE EXTENSION IF NOT EXISTS tsm_system_rows;

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
BEGIN
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
                                                        variation TEXT
                                                        )
RETURNS BOOLEAN
AS $func$
BEGIN
  EXECUTE format('
    UPDATE %I
    SET %I = %I + (2 * random() - 1 ) * %L ::INTERVAL
    ', noise_table, noise_column, noise_column, variation
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
                                                shuffle_column TEXT,
                                                primary_key TEXT
                                                )
RETURNS BOOLEAN
AS $func$
BEGIN

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
-- FIXME sanitize datapath
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
CREATE OR REPLACE FUNCTION @extschema@.partial(ov TEXT, prefix INT, padding TEXT, suffix INT)
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
-- The main goal is to avoid any complex regexp by splitting the job into simpler tasks
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
-- Masking
-------------------------------------------------------------------------------

-- List of all the masked columns
CREATE OR REPLACE VIEW @extschema@.pg_masks AS
WITH const AS (
    SELECT
        '%MASKED +WITH +FUNCTION +#"%#(%#)#"%'::TEXT AS pattern_mask_column_function,
        '%MASKED +WITH +CONSTANT +#"%#(%#)#"%'::TEXT AS pattern_mask_column_constant
)
SELECT
  a.attrelid,
  a.attname,
  c.oid AS relid,
  c.relname,
  pg_catalog.format_type(a.atttypid, a.atttypmod),
  pg_catalog.col_description(a.attrelid, a.attnum),
  substring(pg_catalog.col_description(a.attrelid, a.attnum) from k.pattern_mask_column_function for '#')  AS masking_function,
  substring(pg_catalog.col_description(a.attrelid, a.attnum) from k.pattern_mask_column_constant for '#')  AS masking_constant
FROM const k,
     pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
WHERE a.attnum > 0
--  TODO : Filter out the catalog tables
AND NOT a.attisdropped
AND (
    pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_function ESCAPE '#'
OR  pg_catalog.col_description(a.attrelid, a.attnum) SIMILAR TO k.pattern_mask_column_constant ESCAPE '#'
)
;

-- Adds a `hasmask` column to the pg_roles catalog
-- True if the role is masked, else False
CREATE OR REPLACE VIEW @extschema@.pg_masked_roles AS
SELECT r.*,
    COALESCE(shobj_description(r.oid,'pg_authid') SIMILAR TO '%MASKED%',false) AS hasmask
FROM pg_roles r
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

-- Walk through all masked columns and permanently apply the mask
-- This is not a "masking function" per se, but it relies on the masking infra
CREATE OR REPLACE FUNCTION @extschema@.anonymize()
RETURNS BOOLEAN
AS $$
DECLARE
    col RECORD;
BEGIN
  IF not @extschema@.isloaded() THEN
	RAISE NOTICE 'The faking data is not loaded. You probably need to run ''SELECT @extschema@.load()'' ';
  END IF;

  FOR col IN
    SELECT * FROM @extschema@.pg_masks
  LOOP
    RAISE DEBUG 'Anonymize %.% with %', col.relid::regclass,col.attname, col.masking_function;
    EXECUTE format('UPDATE %s SET %I = %s', col.relid::regclass,col.attname, col.masking_function);
  END LOOP;
  RETURN TRUE;
END;
$$
LANGUAGE plpgsql VOLATILE;

-- Backward compatibility
CREATE OR REPLACE FUNCTION @extschema@.static_substitution()
RETURNS BOOLEAN AS
$$
SELECT @extschema@.anonymize();
$$
LANGUAGE SQL VOLATILE;

-- True if the role is masked
CREATE OR REPLACE FUNCTION @extschema@.hasmask(role REGROLE)
RETURNS BOOLEAN AS
$$
SELECT hasmask
FROM @extschema@.pg_masked_roles
WHERE rolname = role::NAME;
$$
LANGUAGE SQL VOLATILE;

-- Display all columns of the relation with the masking function (if any)
CREATE OR REPLACE FUNCTION @extschema@.mask_columns(source_relid OID)
RETURNS TABLE (
    attname NAME,
    masking_function TEXT
) AS
$$
SELECT
	a.attname::NAME, -- explicit cast for PG 9.6
	m.masking_function
FROM pg_attribute a
LEFT JOIN anon.pg_masks m ON m.relid = a.attrelid AND m.attname = a.attname
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
CREATE OR REPLACE FUNCTION  @extschema@.mask_create(sourceschema NAME, maskschema TEXT)
RETURNS SETOF VOID AS
$$
BEGIN
  -- Be sure that the target schema is here
  IF NOT EXISTS (
	-- CREATE SCHEMA already has a clause `IF NOT EXITS` !
    -- but it will output a NOTICE message for each call of `mask_create`.
    -- This function will be called after every DDL event
    -- to avoid unecessary NOTICE messages, we check if 
    -- the schema is present and call `CREATE SCHEMA` only if needed
    SELECT
    FROM information_schema.schemata
    WHERE schema_name = maskschema
  )
  THEN
    EXECUTE format('CREATE SCHEMA %I',maskschema);
  END IF;


  -- Walk through all tables in the source schema
  PERFORM @extschema@.mask_create_view(oid) 
  FROM pg_class
  WHERE relnamespace=sourceschema::regnamespace
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
            expression := expression || m.masking_function || ' AS ' || quote_ident(m.attname);
        END IF;
        comma := ',';
    END LOOP;
	RETURN expression;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Build a masked view for a table
CREATE OR REPLACE FUNCTION @extschema@.mask_create_view( relid OID)
RETURNS BOOLEAN AS
$$
BEGIN
    EXECUTE format('CREATE OR REPLACE VIEW %s.%s AS SELECT %s FROM %s',
																	@extschema@.mask_schema()::REGNAMESPACE,
																	relid::REGCLASS,
																	@extschema@.mask_filters(relid),
																	relid::REGCLASS);
	RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- Activate the masking engine
-- FIXME sanitize maskschema
CREATE OR REPLACE FUNCTION @extschema@.mask_init(
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

  UPDATE @extschema@.config SET value=sourceschema WHERE param='sourceschema';
  UPDATE @extschema@.config SET value=maskschema WHERE param='maskschema';

  PERFORM @extschema@.mask_update();
  RETURN TRUE;
END
$$
LANGUAGE plpgsql VOLATILE;

-- TODO 
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

-- Mask all roles
CREATE OR REPLACE FUNCTION @extschema@.mask_roles()
RETURNS SETOF VOID AS
$$
    SELECT @extschema@.mask_role(rolname::REGROLE)
    FROM @extschema@.pg_masked_roles
    WHERE hasmask;
$$
LANGUAGE SQL VOLATILE;

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
LANGUAGE plpgsql VOLATILE;

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
LANGUAGE plpgsql VOLATILE;

-- Rebuild the masking views from scratch
CREATE OR REPLACE FUNCTION @extschema@.mask_update()
RETURNS SETOF VOID AS
$$
    SELECT @extschema@.mask_disable();
    SELECT @extschema@.mask_create(@extschema@.source_schema(),@extschema@.mask_schema());
    SELECT @extschema@.mask_roles();
    SELECT @extschema@.mask_enable();
$$
LANGUAGE SQL VOLATILE;

-------------------------------------------------------------------------------
-- Dumping
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION @extschema@.dump_ddl()
RETURNS TABLE (
    ddl TEXT
) AS
$$
    SELECT ddlx_create(oid)
    FROM pg_class
    WHERE relkind != 't' -- exclude the TOAST objects
    AND relnamespace IN (
      SELECT oid
      FROM pg_namespace
      WHERE nspname NOT LIKE 'pg_%'
      AND nspname NOT IN ( 'information_schema' , '@extschema@' , @extschema@.mask_schema()) 
    )
	ORDER BY array_position(ARRAY['S','t'], relkind::TEXT), oid::regclass  -- drop [S]equences before [t]ables
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
  copy_statement := format(E'COPY %s  FROM STDIN CSV QUOTE AS ''"'' DELIMITER '',''; \n', relid::REGCLASS);
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
