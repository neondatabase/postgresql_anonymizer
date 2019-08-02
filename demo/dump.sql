-- STEP 0: Basic Example
CREATE TABLE cluedo ( name TEXT, weapon TEXT, room TEXT);
INSERT INTO cluedo VALUES
('Colonel Mustard','Candlestick', 'Kitchen'),
('Professor Plum', 'Revolver', 'Ballroom'),
('Miss Scarlett', 'Dagger', 'Lounge'),
('Mrs. Peacock', 'Rope', 'Dining Room');
SELECT * FROM cluedo;

-- STEP 1 : Load the extension
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();

-- STEP  : Declare the masking rules
COMMENT ON COLUMN cluedo.name IS 'MASKED WITH FUNCTION anon.random_last_name()';

-- STEP 4 : Dump
SELECT anon.dump();

-- STEP 5 : Clean up
DROP EXTENSION anon CASCADE;
