BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- This will throw an error and break the transaction
SELECT anon.load('./does/not/exists/cd2ks3s/'); 

ROLLBACK;


BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.isloaded() IS FALSE; 

SELECT anon.load();

SELECT anon.isloaded() IS TRUE;

SELECT anon.unload();

SELECT anon.isloaded() IS FALSE;

SELECT anon.mask_init( autoload := FALSE);

SELECT anon.isloaded() IS FALSE;

ROLLBACK;
