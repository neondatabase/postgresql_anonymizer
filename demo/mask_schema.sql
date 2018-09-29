

CREATE OR REPLACE FUNCTION mask_create_schema(source TEXT, mask TEXT)
RETURNS SETOF VOID AS
$$
BEGIN
	RAISE 'CREATE SCHEMA mask';
--	LOOP private
--		mask_table(private.t, mask.t)
--	END
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION masks_of_table(sourcetable TEXT)
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
and table_schema='public' --FIXME
-- FIXME : FILTER schema_name on anon.mask too
;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION  mask_create(sourceschema TEXT DEFAULT 'public', maskschema TEXT DEFAULT 'mask')
RETURNS SETOF VOID AS
$$
DECLARE
	t RECORD;
BEGIN
	FOR  t IN SELECT * FROM pg_tables WHERE schemaname = 'public'
	LOOP
		EXECUTE format('SELECT mask_create_view(%L,%L);',t.tablename,maskschema);
	END LOOP;
END
$$
LANGUAGE plpgsql;  

CREATE OR REPLACE FUNCTION mask_create_view(sourcetable TEXT, maskschema TEXT DEFAULT 'mask')
RETURNS SETOF VOID AS
$$
DECLARE
	m RECORD;
	expression TEXT;
	comma TEXT;
BEGIN
	expression := '';
	comma := '';
	FOR m IN SELECT * FROM masks_of_table(sourcetable)
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


-- hasmask()

CREATE OR REPLACE VIEW pg_masked_roles AS
SELECT r.*,
	COALESCE(shobj_description(r.oid,'pg_authid') SIMILAR TO '% *MASK %',false) AS hasmask
FROM pg_roles r
;

CREATE OR REPLACE FUNCTION hasmask(role TEXT)
RETURNS BOOLEAN AS
$$
SELECT hasmask FROM pg_masked_roles WHERE rolname = quote_ident(role);
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION mask_private_t1()
RETURNS SETOF private.t1 AS
$$
BEGIN
  IF hasmask(USER) THEN RETURN QUERY SELECT * FROM mask.t1;
  ELSE RETURN QUERY SELECT * FROM private.t1;
  END IF;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mask_add_role(role TEXT, source TEXT, mask TEXT)
RETURNS SETOF VOID AS
$$
BEGIN
	RAISE DEBUG 'Source = %', source;
	EXECUTE format('REVOKE ALL ON SCHEMA %I FROM %I', source, role);
	EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', 'anon', role);
	EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', 'anon', role);
	EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', mask, role);
	EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', mask, role);
	EXECUTE format('ALTER ROLE %I SET search_path TO %I,public;', role, mask);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION mask_update()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Function can retuen EVENT_TRIGGER, we're forced to make a plpgsql function
-- For now, create = update
BEGIN	
	PERFORM mask_disable();
	PERFORM mask_create();
	PERFORM mask_enable();
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mask_enable()
RETURNS SETOF VOID AS
$$
CREATE EVENT TRIGGER mask_update ON ddl_command_end EXECUTE PROCEDURE mask_update();
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION mask_disable()
RETURNS SETOF VOID AS
$$
DROP EVENT TRIGGER mask_update;
$$
LANGUAGE SQL;

--
-- CANT USE A WHERE CLAUSE ON SLECT RULES
-- CANT PUT A SELECT RULE IF THE TABLE CONTAINS DATA
--
--CREATE RULE "_RETURN" AS
--ON SELECT TO t1
--DO INSTEAD
--SELECT * FROM mask_t1
--;

--
--  T E S T S
--

CREATE TABLE t1 (
    id SERIAL,
    name TEXT,
    "CreditCard" TEXT,
    fk_company INTEGER
);

INSERT INTO t1
VALUES (1,'Schwarzenegger','1234567812345678', 1991);


COMMENT ON COLUMN t1.name IS '  MASKED WITH (   FUNCTION = anon.random_last_name() )';
COMMENT ON COLUMN t1."CreditCard" IS '  MASKED WITH (   FUNCTION = anon.random_string(12) )';

COMMENT ON ROLE postgres IS 'UNMASK';

SELECT mask_create(); 



