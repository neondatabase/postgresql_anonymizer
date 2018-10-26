-- STEP 1 : Activate the masking engine
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.mask_init();

-- STEP 2 : Declare a masked user
CREATE ROLE skynet LOGIN;
COMMENT ON ROLE skynet IS 'MASKED';

-- STEP 3 : Declare the masking rules
CREATE TABLE people ( id TEXT, name TEXT, phone TEXT);
INSERT INTO people VALUES ('T800','Schwarzenegger','0609110911');
SELECT * FROM people;

-- STEP 3 : Declare the masking rules 
COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';
COMMENT ON COLUMN people.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';

-- STEP 4 : Connect with the masked user
\! psql demo -U skynet -c 'SELECT * FROM people;'

-- STEP 5 : Clean up
DROP EXTENSION anon CASCADE;
REASSIGN OWNED BY skynet TO postgres;
DROP OWNED BY skynet;
DROP ROLE skynet;
