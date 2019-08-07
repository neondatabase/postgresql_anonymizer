BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.isloaded() IS FALSE;

-- returns a WARNING and FALSE
SELECT anon.load('./does/not/exists/cd2ks3s/') IS FALSE; 

SELECT anon.isloaded() IS FALSE; 

SELECT anon.load();

SELECT anon.isloaded() IS TRUE;

SELECT anon.unload();

SELECT anon.isloaded() IS FALSE;

SELECT anon.start_dynamic_masking( autoload := FALSE );

SELECT anon.isloaded() IS FALSE;

ROLLBACK;
