BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.is_initialized() IS FALSE;

-- basic usage
SELECT anon.init();
SELECT anon.is_initialized();
SELECT anon.reset();

-- returns a WARNING and FALSE
SELECT anon.init('./does/not/exists/cd2ks3s/') IS FALSE;
SELECT anon.is_initialized() IS FALSE;

-- load alternate data dir
\! cp -pr data/default $PGDATA/tmp_anon_alternate_data
SELECT anon.init('tmp_anon_alternate_data');
\! rm -fr $PGDATA/tmp_anon_alternate_data
SELECT anon.reset();

-- load an empty data dir
-- returns a lot of NOTICE and FALSE
SELECT anon.init('pg_twophase') IS FALSE;
SELECT anon.is_initialized() IS FALSE;

-- backward compatibility with v0.6 and below
SELECT anon.load();

-- Returns a NOTICE and TRUE
SELECT anon.init();

SELECT anon.is_initialized() IS TRUE;

SELECT anon.reset();

SELECT anon.is_initialized() IS FALSE;

SELECT anon.start_dynamic_masking( autoload := FALSE );

SELECT anon.is_initialized() IS FALSE;

ROLLBACK;
