-- STEP 1 : Activate the masking engine
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();
SELECT anon.mask_init();

-- STEP 2 : Declare the masking rules
CREATE TABLE people ( id TEXT, name TEXT, creditcard TEXT);
INSERT INTO people VALUES ('T800','Schwarzenegger','1234-1234-1234-1234');
COMMENT ON COLUMN people.name IS 'MASKED WITH anon.random_last_name()';
COMMENT ON COLUMN people.creditcard IS 'MASKED WITH $$XXXX-XXXX-XXXX-XXXX$$ ';

-- STEP 3 : Declare a masked user
DROP OWNED BY skynet;
DROP ROLE IF EXISTS skynet;
CREATE ROLE skynet LOGIN;
COMMENT ON ROLE skynet IS 'MASKED';

-- STEP 4 : Enjoy !
\! psql test -U skynet -c 'SELECT * FROM people;'
