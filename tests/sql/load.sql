CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.isloaded() IS FALSE; 

SELECT anon.load();

SELECT anon.isloaded() IS TRUE;

SELECT anon.unload();

SELECT anon.isloaded() IS FALSE;

DROP EXTENSION anon CASCADE;
