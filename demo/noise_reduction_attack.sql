--
-- This is a basic example of a repeat attacks against the noise() masking
-- functions when they're used with dynamic masking.. We will demonstrate how
-- a masked role can guess a real data using only the masking views
--

-- STEP 1 : Activate the masking engine
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.start_dynamic_masking();

-- STEP 2: Declare a masked user
CREATE ROLE attacker LOGIN;
SECURITY LABEL FOR anon ON ROLE attacker IS 'MASKED';

-- STEP 3: Load the data
DROP TABLE IF EXISTS people CASCADE;
CREATE TABLE people ( id INT, name TEXT, age INT);
INSERT INTO people VALUES (157, 'Mike Ehrmantraut' , 63);
INSERT INTO people VALUES (482, 'Jimmy McGill',  47);

-- STEP 4: Declare the masking rules
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH VALUE $$CONFIDENTIAL$$ ';

SECURITY LABEL FOR anon ON COLUMN people.age
IS 'MASKED WITH FUNCTION anon.noise(age, 0.33 )';

-- STEP 5: Connect with the masked user

-- when attacker ask for the age of person #157, he gets a "noised" value
\! psql demo -U attacker -c 'SELECT age FROM people WHERE id = 157'

-- now let's do this 10000 times and get the average
\! psql demo -U attacker -c 'SELECT  avg(age) FROM people, generate_series(1,10000) WHERE id = 157;'

