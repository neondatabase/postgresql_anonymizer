-- This test cannot be run in a single transcation
-- This test must be run on a database named 'contrib_regression'

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Dynamic masking
SELECT anon.start_dynamic_masking();

SELECT anon.set_secret_salt('x');

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
DROP EXTENSION tsm_system_rows;
DROP EXTENSION pgcrypto;

REASSIGN OWNED BY jimmy_mcnulty TO postgres;
DROP OWNED BY jimmy_mcnulty CASCADE;
DROP ROLE jimmy_mcnulty;

