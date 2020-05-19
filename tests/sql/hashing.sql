-- This test cannot be run in a single transcation
-- This test must be run on a database named 'contrib_regression'

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Init
SELECT anon.load();

-- Using the automatic salt
SELECT anon.hash(NULL) IS NULL;
SELECT anon.hash('abcd') = anon.hash('abcd','sha512');

-- With a random salt
SELECT anon.random_hash('abcd') != anon.random_hash('abcd');

-- Restore a predifened salt
SELECT anon.set_secret_salt('4a6821d6z4e33108gg316093e6182b803d0361');

-- Return value is always
SELECT anon.hash('abcd') = '26909982853aafcd56410ae33b70541ee8ed868d7438557f41b28ef062ec22c080ff89a786adde1e2797875e9fa20219ee4f7f076a1f9fc5264241e28a31035b';
SELECT anon.hash('abcd','md5') = 'bb01b7484406325bfa8df2e2f2f8d8fd';
SELECT anon.hash('abcd','sha224') = 'f75dd47c245113ab5734270ac13db1f73f330179b10e57aa6b46457b';
SELECT anon.hash('abcd','sha256') = '3a878e51ae30c795fc04554096c6c05d50771f3c6f7352d950bbba6538892346';
SELECT anon.hash('abcd','sha384') = 'd145dd187e478b2fabbe687c119954d9f166a9461319e300ac51ad2ec5ee54a71f39e0ef654ff20098efadf40e5df394';

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

