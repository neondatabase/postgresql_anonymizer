--
-- # Legacy Dynamic Masking
--
-- This code is the first implementation of Dynamic Masking and was developed
-- in early versions of the extension. This implementation has several
-- drawbacks and limitations. It is now replaced by Transparent Dynamic Masking
-- which better, safer and faster.
--
-- We keep this code in version 2.x for backward compatibility but we won't
-- put much effort to maintain it and we won't accept new features on this
-- part of the code.
--
-- This implementation will be deprecated in version 3
--

-- True if the role is masked
CREATE OR REPLACE FUNCTION anon.hasmask(
  role REGROLE,
  masking_policy TEXT DEFAULT 'anon'
)
RETURNS BOOLEAN AS
$$
SELECT bool_or(m.masked)
FROM (
  -- Rule from SECURITY LABEL
  SELECT label ILIKE 'MASKED' AS masked
  FROM pg_catalog.pg_shseclabel
  WHERE  objoid = role
  AND provider = masking_policy
  UNION
  -- return FALSE if the SELECT above is empty
  SELECT FALSE as masked --
) AS m
$$
  LANGUAGE SQL
  STABLE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.hasmask IS 'UNTRUSTED';

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
FROM pg_catalog.pg_attribute a
LEFT JOIN  anon.pg_masking_rules m
        ON m.attrelid = a.attrelid
        AND m.attname = a.attname
WHERE  a.attrelid = source_relid
AND    a.attnum > 0 -- exclude ctid, cmin, cmax
AND    NOT a.attisdropped
ORDER BY a.attnum
;
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.mask_columns IS 'UNTRUSTED';

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
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.mask_filters IS 'UNTRUSTED';

-- Build a SELECT query masking the real data
CREATE OR REPLACE FUNCTION anon.mask_select(
  relid OID
)
RETURNS TEXT AS
$$
  SELECT format(  'SELECT %s FROM %s %s',
                  anon.mask_filters(relid),
                  relid::REGCLASS,
                  anon.get_tablesample_ratio(relid)
  );
$$
  LANGUAGE SQL
  VOLATILE
  PARALLEL SAFE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.mask_select IS 'UNTRUSTED';

-- Build a masked view for a table
CREATE OR REPLACE FUNCTION anon.mask_create_view(
  relid OID
)
RETURNS BOOLEAN AS
$$
DECLARE
  rel_is_view BOOLEAN;
BEGIN
  --
  -- Masking rules on a view is not supported
  --
  SELECT relkind = 'v' INTO rel_is_view
    FROM pg_catalog.pg_class
    WHERE oid=relid;

  IF rel_is_view THEN
    RAISE EXCEPTION 'Masking a view is not supported.';
  END IF;

  EXECUTE format( 'CREATE OR REPLACE VIEW %I.%s AS %s',
                  pg_catalog.current_setting('anon.maskschema'),
                  -- FIXME quote_ident(relid::REGCLASS::TEXT) ?
                  ( SELECT quote_ident(relname)
                    FROM pg_catalog.pg_class
                    WHERE relid = oid
                  ),
                  anon.mask_select(relid)
  );
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of CREATE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION  anon.mask_create_view IS 'UNTRUSTED';

-- Remove a masked view for a given table
CREATE OR REPLACE FUNCTION anon.mask_drop_view(
  relid OID
)
RETURNS BOOLEAN AS
$$
BEGIN
  EXECUTE format('DROP VIEW %I.%s;',
                  pg_catalog.current_setting('anon.maskschema'),
                  -- FIXME quote_ident(relid::REGCLASS::TEXT) ?
                  ( SELECT quote_ident(relname)
                    FROM pg_catalog.pg_class
                    WHERE relid = oid
                  )
  );
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of DROP
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION  anon.mask_drop_view IS 'UNTRUSTED';

-- Activate the masking engine
CREATE OR REPLACE FUNCTION anon.start_dynamic_masking(
  autoload BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN

  SELECT current_setting('is_superuser') = 'on' AS su INTO r;
  IF NOT r.su THEN
    RAISE EXCEPTION 'Only supersusers can start the dynamic masking engine.';
  END IF;

  -- Load faking data
  SELECT anon.is_initialized() AS init INTO r;
  IF NOT autoload THEN
    RAISE DEBUG 'Autoload is disabled.';
  ELSEIF r.init THEN
    RAISE DEBUG 'Anon extension is already initialized.';
  ELSE
    PERFORM anon.init();
  END IF;

  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I',
                  pg_catalog.current_setting('anon.maskschema')::NAME
  );

  PERFORM anon.mask_update();

  RETURN TRUE;

  EXCEPTION
    WHEN invalid_name THEN
       RAISE EXCEPTION '% is not a valid name',
                        pg_catalog.current_setting('anon.maskschema')::NAME;

END
$$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.start_dynamic_masking IS 'UNTRUSTED';

-- this is opposite of start_dynamic_masking()
CREATE OR REPLACE FUNCTION anon.stop_dynamic_masking()
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN

  SELECT current_setting('is_superuser') = 'on' AS su INTO r;
  IF NOT r.su THEN
    RAISE EXCEPTION 'Only supersusers can stop the dynamic masking engine.';
  END IF;

  -- Walk through all tables in the source schema and drop the masking view
  PERFORM anon.mask_drop_view(oid)
  FROM pg_catalog.pg_class
  WHERE relnamespace=quote_ident(pg_catalog.current_setting('anon.sourceschema'))::REGNAMESPACE
  AND relkind IN ('r','p','f') -- relations or partitions or foreign tables
  ;

  -- Walk through all masked roles and remove their mask
  PERFORM anon.unmask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE anon.hasmask(oid::REGROLE);

  -- Drop the masking schema, it should be empty
  EXECUTE format('DROP SCHEMA IF EXISTS %I',
                  pg_catalog.current_setting('anon.maskschema')
  );

  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  VOLATILE
  PARALLEL UNSAFE -- because of DROP
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.stop_dynamic_masking IS 'UNTRUSTED';


-- This is run after any changes in the data model
CREATE OR REPLACE FUNCTION anon.trg_mask_update()
RETURNS EVENT_TRIGGER AS
$$
-- SQL Functions cannot return EVENT_TRIGGER,
-- we're forced to write a plpgsql function
BEGIN
  PERFORM anon.mask_update();
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.trg_mask_update IS 'UNTRUSTED';

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
  SELECT quote_ident(pg_catalog.current_setting('anon.sourceschema'))::REGNAMESPACE
    INTO sourceschema;
  SELECT quote_ident(pg_catalog.current_setting('anon.maskschema'))::REGNAMESPACE
    INTO maskschema;
  RAISE DEBUG 'Mask role % (% -> %)', maskedrole, sourceschema, maskschema;
  -- The masked role cannot read the authentic data in the source schema
  EXECUTE format('REVOKE ALL ON SCHEMA %s FROM %s', sourceschema, maskedrole);
  -- The masked role can use the anon schema
  EXECUTE format('GRANT USAGE ON SCHEMA anon TO %s', maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA anon TO %s', maskedrole);
  EXECUTE format('GRANT SELECT ON ALL SEQUENCES IN SCHEMA anon TO %s', maskedrole);
  -- The masked role can use the masking schema
  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', maskschema, maskedrole);
  EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s', maskschema, maskedrole);
  -- This is how we "trick" the masked role
  EXECUTE format('ALTER ROLE %s SET search_path TO %s,%s;', maskedrole, maskschema,sourceschema);
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of ALTER
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.mask_role IS 'UNTRUSTED';

-- Remove (partially) the mask of a specific role
CREATE OR REPLACE FUNCTION anon.unmask_role(
  maskedrole REGROLE
)
RETURNS BOOLEAN AS
$$
BEGIN
  -- we dont know what privileges this role had before putting his mask on
  -- so we keep most of the privileges as they are and let the
  -- administrator restore the correct access right.
  RAISE NOTICE 'The previous privileges of ''%'' are not restored. You need to grant them manually.', maskedrole;
  -- restore default search_path
  EXECUTE format('ALTER ROLE %s RESET search_path;', maskedrole);
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.unmask_role IS 'UNTRUSTED';

CREATE OR REPLACE FUNCTION anon.mask_update()
RETURNS BOOLEAN AS
$$
BEGIN
  -- Check if dynamic masking is enabled
  PERFORM nspname
  FROM pg_catalog.pg_namespace
  WHERE nspname = pg_catalog.current_setting('anon.maskschema', true)::NAME;

  IF NOT FOUND THEN
    -- Dynamic masking is disabled, no need to go further
    RETURN FALSE;
  END IF;

  --
  -- Until Postgres 16, users could manually transform a table into a view
  -- using a basic CREATE RULE statement. Placing a masking rule on a view is
  -- not supported, however a very stubborn user could try to create a table,
  -- put a mask on it and then transform the table into a view. In that case,
  -- the mask_update process is stopped immediately
  --
  -- https://github.com/postgres/postgres/commit/b23cd185fd5410e5204683933f848d4583e34b35
  --
  PERFORM c.oid
  FROM pg_catalog.pg_class c
  JOIN anon.pg_masking_rules mr ON c.oid = mr.attrelid
  WHERE c.relkind='v';

  IF FOUND THEN
    RAISE EXCePTION 'Masking a view is not supported.';
  END IF;

  -- Walk through all tables in the source schema
  -- and build a dynamic masking view
  PERFORM anon.mask_create_view(oid)
  FROM pg_catalog.pg_class
  WHERE relnamespace=quote_ident(pg_catalog.current_setting('anon.sourceschema'))::REGNAMESPACE
  AND relkind IN ('r','p','f') -- relations or partitions or foreign tables
  ;

  -- Walk through all masked roles and apply the restrictions
  PERFORM anon.mask_role(oid::REGROLE)
  FROM pg_catalog.pg_roles
  WHERE anon.hasmask(oid::REGROLE);

  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of UPDATE
  SECURITY DEFINER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.mask_update IS 'UNTRUSTED';

--
-- Unmask all the role at once
--
CREATE OR REPLACE FUNCTION anon.remove_masks_for_all_roles()
RETURNS BOOLEAN AS
$$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT rolname
           FROM anon.pg_masked_roles
           WHERE hasmask
  LOOP
    EXECUTE format('SECURITY LABEL FOR anon ON ROLE %I IS NULL', r.rolname);
  END LOOP;
  RETURN TRUE;
END
$$
  LANGUAGE plpgsql
  PARALLEL UNSAFE -- because of SECURITY LABEL
  SECURITY INVOKER
  SET search_path=''
;

SECURITY LABEL FOR anon ON FUNCTION anon.remove_masks_for_all_roles IS 'UNTRUSTED';

--
-- Trigger the mask_update on any major schema changes
--
-- Complete list of TAGs is available here:
-- https://www.postgresql.org/docs/current/event-trigger-matrix.html
--
CREATE EVENT TRIGGER anon_trg_mask_update
  ON ddl_command_end
  WHEN TAG IN (
    'ALTER TABLE', 'CREATE TABLE', 'CREATE TABLE AS', 'DROP TABLE',
    'ALTER MATERIALIZED VIEW', 'CREATE MATERIALIZED VIEW', 'DROP MATERIALIZED VIEW',
    'ALTER FOREIGN TABLE', 'CREATE FOREIGN TABLE', 'DROP FOREIGN TABLE',
    'SECURITY LABEL', 'SELECT INTO',
    'CREATE RULE', 'ALTER RULE', 'DROP RULE'
  )
  EXECUTE PROCEDURE anon.trg_mask_update()
  -- EXECUTE FUNCTION not supported by PG10 and below
;
