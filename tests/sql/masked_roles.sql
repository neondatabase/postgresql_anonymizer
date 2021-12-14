-- This test cannot be run in a single transaction
-- This test must be run on a database named 'contrib_regression'

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.start_dynamic_masking('public','foo');

CREATE ROLE skynet LOGIN;

SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';

SELECT anon.mask_update();

-- search_path must be 'foo,public'
\! psql contrib_regression -U skynet -c 'SHOW search_path;'


CREATE ROLE hal LOGIN;

COMMENT ON ROLE hal IS 'MASKED';

SELECT anon.mask_update();

-- search_path must be 'foo,public'
\! psql contrib_regression -U hal -c 'SHOW search_path;'

-- STOP

SELECT anon.stop_dynamic_masking();

--  CLEAN

DROP EXTENSION anon CASCADE;
DROP EXTENSION pgcrypto;

REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet CASCADE;
DROP ROLE skynet;

REASSIGN OWNED BY hal TO postgres;
DROP OWNED BY hal CASCADE;
DROP ROLE hal;

