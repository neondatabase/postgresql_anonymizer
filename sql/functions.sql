

--
--
--

--
-- LOAD / UNLOAD
--

-- load fake data from a given path
CREATE OR REPLACE FUNCTION load(datapath TEXT)
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
CREATE OR REPLACE FUNCTION load()
RETURNS void AS $$
	WITH conf AS (
		SELECT setting AS sharedir
		FROM pg_config
		WHERE name = 'SHAREDIR'
	)
	SELECT @extschema@.load(conf.sharedir || '/extension/anon/data/default/')
	FROM conf;
$$
LANGUAGE SQL VOLATILE;

-- FIXME
SELECT pg_catalog.pg_extension_config_dump('@extschema@.city','');

-- remove all fake data
CREATE OR REPLACE FUNCTION unload()
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

--
-- Generic Types
--

CREATE OR REPLACE FUNCTION random_string(l integer)
RETURNS text AS $$ SELECT array_to_string(
			array(
				select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',((random()*(36-1)+1)::integer),1)
				from generate_series(1,l)
			),''
		  ); $$
LANGUAGE SQL VOLATILE;

-- Zip code
CREATE OR REPLACE FUNCTION random_zip()
RETURNS text AS $$ SELECT array_to_string(
            array(
                select substr('0123456789',((random()*(10-1)+1)::integer),1)
                from generate_series(1,5)
            ),''
          ); $$
LANGUAGE SQL VOLATILE;


-- date

CREATE OR REPLACE FUNCTION random_date_between(date_start timestamp WITH TIME ZONE, date_end timestamp WITH TIME ZONE)
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

CREATE OR REPLACE FUNCTION random_int_between(int_start INTEGER, int_stop INTEGER)
RETURNS INTEGER AS $$
	SELECT CAST ( random()*(int_stop-int_start)+int_start AS INTEGER );
$$
LANGUAGE SQL VOLATILE;

--
-- Personal data : First Name, Last Name, etc.
--

CREATE OR REPLACE FUNCTION random_first_name()
RETURNS TEXT AS $$
	SELECT first_name FROM @extschema@.first_name TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_last_name()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_email()
RETURNS TEXT AS $$
	SELECT address FROM @extschema@.email TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_city_in_country(country_name TEXT)
RETURNS TEXT AS $$
	SELECT name FROM @extschema@.city WHERE country=country_name ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_city()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_region_in_country(country_name TEXT)
RETURNS TEXT AS $$
    SELECT subcountry FROM @extschema@.city WHERE country=country_name ORDER BY random() LIMIT 1;
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_region()
RETURNS TEXT AS $$
    SELECT subcountry FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_country()
RETURNS TEXT AS $$
    SELECT country FROM @extschema@.city TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION random_phone( phone_prefix TEXT DEFAULT '0' )
RETURNS TEXT AS $$
	SELECT phone_prefix || CAST(@extschema@.random_int_between(100000000,999999999) AS TEXT) AS "phone";
$$
LANGUAGE SQL VOLATILE;


--
-- Company data : Name, SIRET, IBAN, etc.
--

CREATE OR REPLACE FUNCTION random_company()
RETURNS TEXT AS $$
    SELECT name FROM @extschema@.company TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_iban()
RETURNS TEXT AS $$
    SELECT id FROM @extschema@.iban TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_siren()
RETURNS TEXT AS $$
    SELECT siren FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

CREATE OR REPLACE FUNCTION random_siret()
RETURNS TEXT AS $$
	SELECT siren||nic FROM @extschema@.siret TABLESAMPLE SYSTEM_ROWS(1);
$$
LANGUAGE SQL VOLATILE;

