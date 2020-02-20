BEGIN;

CREATE SCHEMA dbo;

CREATE TABLE dbo.tbl1 AS
SELECT
    1234 AS staff_id,
    'John' AS firstname,
    'Doe'  AS lastname,
    'john@doe.com' AS email
;



SECURITY LABEL FOR anon ON COLUMN dbo.tbl1.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

SELECT lastname = 'Doe' FROM dbo.tbl1;

-- Test with the masked schema in the search path

SET search_path=dbo,public;

SELECT anon.start_dynamic_masking('dbo', 'dbo_mask');

SELECT lastname != 'Doe' FROM dbo_mask.tbl1;

SELECT anon.stop_dynamic_masking();

-- Test WITHOUT the masked schema in the search path

SET search_path=public;

SELECT anon.start_dynamic_masking('dbo', 'dbo_mask_2');

SELECT lastname != 'Doe' FROM dbo_mask_2.tbl1;

SELECT anon.stop_dynamic_masking();

ROLLBACK;


