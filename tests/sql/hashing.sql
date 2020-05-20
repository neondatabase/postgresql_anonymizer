-- This test cannot be run in a single transcation
-- This test must be run on a database named 'contrib_regression'

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Init
SELECT anon.load();

--
-- Using the automatic salt and default algorithm
--
SELECT anon.hash(NULL) IS NULL;

SELECT anon.hash('x')
     = anon.digest('x',anon.get_secret_salt(), anon.get_secret_algorithm());

--
-- With a random salt
--
SELECT anon.random_hash('abcd') != anon.random_hash('abcd');

-- Restore a predifened salt and change the algo
SELECT anon.set_secret_salt('4a6821d6z4e33108gg316093e6182b803d0361');
SELECT anon.set_secret_algorithm('md5');
SELECT anon.hash('x');
SELECT anon.set_secret_algorithm('sha512');
SELECT anon.hash('x');

-- digest
SELECT anon.digest(NULL,'b','sha1') IS NULL;
SELECT anon.digest('a',NULL,'sha1') IS NULL;
SELECT anon.digest('a','b',NULL) IS NULL;

SELECT anon.digest('a','b','md5') = '187ef4436122d1cc2f40dc2b92f0eba0';
SELECT anon.digest('a','b','sha1') = 'da23614e02469a0d7c7bd1bdab5c9c474b1904dc';
SELECT anon.digest('a','b','sha224') = 'db3cda86d4429a1d39c148989566b38f7bda0156296bd364ba2f878b';
SELECT anon.digest('a','b','sha256') = 'fb8e20fc2e4c3f248c60c39bd652f3c1347298bb977b8b4d5903b85055620603';
SELECT anon.digest('a','b','sha384') = 'c7be03ba5bcaa384727076db0018e99248e1a6e8bd1b9ef58a9ec9dd4eeebb3f48b836201221175befa74ddc3d35afdd';
SELECT anon.digest('a','b','sha512') = '2d408a0717ec188158278a796c689044361dc6fdde28d6f04973b80896e1823975cdbf12eb63f9e0591328ee235d80e9b5bf1aa6a44f4617ff3caf6400eb172d';

-- Dynamic masking
SELECT anon.start_dynamic_masking();

CREATE TABLE phone (
  phone_owner  TEXT,
  phone_number TEXT
);

INSERT INTO phone VALUES
('Omar Little','410-719-9009'),
('Russell Bell','410-617-7308'),
('Avon Barksdale','410-385-2983');

CREATE TABLE phonecall (
  call_id INT,
  call_sender TEXT,
  call_receiver TEXT,
  call_start_time TIMESTAMP WITH TIME ZONE,
  call_end_time TIMESTAMP WITH TIME ZONE
);

INSERT INTO phonecall VALUES
(834,'410-617-7308','410-385-2983','2004-05-17 09:41:01.859137+00','2004-05-17 09:44:24.119237+00'),
(835,'410-385-2983','410-719-9009','2004-05-17 11:22:51.859137+00','2004-05-17 11:34:18.119237+00');

SECURITY LABEL FOR anon ON COLUMN phone.phone_owner
IS 'MASKED WITH FUNCTION concat(anon.pseudo_first_name(phone_owner),$$ $$,anon.pseudo_last_name(phone_owner))';

SECURITY LABEL FOR anon ON COLUMN phone.phone_number
IS 'MASKED WITH FUNCTION anon.hash(phone_number)';

SECURITY LABEL FOR anon ON COLUMN phonecall.call_sender
IS 'MASKED WITH FUNCTION anon.hash(call_sender)';

SECURITY LABEL FOR anon ON COLUMN phonecall.call_receiver
IS 'MASKED WITH FUNCTION anon.hash(call_receiver)';


-- ROLE

CREATE ROLE jimmy_mcnulty LOGIN;

SECURITY LABEL FOR anon ON ROLE jimmy_mcnulty IS 'MASKED';

SELECT anon.mask_update();

-- Jimmy reads the phone book
\! psql contrib_regression -U jimmy_mcnulty -c 'SELECT * FROM phone'

-- Jimmy joins table to get the call history
\! psql contrib_regression -U jimmy_mcnulty -c 'SELECT p1.phone_owner as "from", p2.phone_owner as "to", c.call_start_time FROM phonecall c JOIN phone p1 ON c.call_sender = p1.phone_number JOIN phone p2 ON c.call_receiver = p2.phone_number'

-- Jimmy tries to find the salt :-)
\! psql contrib_regression -U jimmy_mcnulty -c 'SELECT anon.get_secret_salt();'


-- Jimmy cant read the secrets
--
-- Here we use a trick to catch to output because the error message is different
-- between versions of PostgreSQL...
-- see tests/sql/masking.sql for more details
--
\! psql contrib_regression -U jimmy_mcnulty -c 'SELECT * FROM anon.secret' 2>&1 | grep --silent 'ERROR:  permission denied' && echo 'ERROR:  permission denied'




-- STOP

SELECT anon.stop_dynamic_masking();

--  CLEAN

DROP TABLE phonecall CASCADE;
DROP TABLE phone CASCADE;

DROP EXTENSION anon CASCADE;

REASSIGN OWNED BY jimmy_mcnulty TO postgres;
DROP OWNED BY jimmy_mcnulty CASCADE;
DROP ROLE jimmy_mcnulty;

