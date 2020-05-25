BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.isloaded() IS FALSE;

-- returns a WARNING and FALSE
SELECT anon.load('./does/not/exists/cd2ks3s/') IS FALSE;

SELECT anon.isloaded() IS FALSE;

-- load alternate data dir
\! cp -pr data/default $PGDATA/tmp_anon_alternate_data

SELECT anon.load('tmp_anon_alternate_data');

\! rm -fr $PGDATA/tmp_anon_alternate_data

SELECT anon.unload();

-- load empty data dir
-- returns a lot of NOTICE and FALSE
SELECT anon.load('pg_twophase');

--

SELECT anon.isloaded() IS FALSE;

SELECT anon.load();

-- Returns a NOTICE and TRUE
SELECT anon.load();

SELECT anon.isloaded() IS TRUE;

SELECT anon.unload();

SELECT anon.isloaded() IS FALSE;

SELECT anon.start_dynamic_masking( autoload := FALSE );

SELECT anon.isloaded() IS FALSE;

ROLLBACK;
