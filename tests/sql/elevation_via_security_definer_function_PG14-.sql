--
-- This test decribes a known elevation attack allowing a masked role to bypass
-- a masking rules and access personal identifiable information (PII)
--
-- THIS IS NOT A SECURITY ISSUE.
-- THIS IS THE EXPECTED BEHAVIOUR.
--
-- This attack requires
--
-- - a compromise role in the database
-- - CREATE/EXECUTE privilege by default for regular roles, which is considered
--   to be a bad practice since 2018
--

BEGIN;

CREATE EXTENSION anon;

SET anon.transparent_dynamic_masking TO TRUE;

CREATE TABLE t AS SELECT 1 AS one;

SECURITY LABEL FOR anon ON COLUMN t.one IS 'MASKED WITH VALUE 0';


--
-- beavis is a masked role. He is not allowed to view personal identifiable
-- information (PII)
-- beavis is not a trusted user
--
CREATE ROLE beavis LOGIN;

SECURITY LABEL FOR anon ON ROLE beavis is 'MASKED';

GRANT SELECT ON TABLE t TO beavis;

--
-- butthead is an unmasked role. He is allowed to access PII
-- butthead is a trusted user but also a traitor, he is going to provide access
-- the PII to beavis
--

CREATE ROLE butthead LOGIN;

GRANT USAGE ON SCHEMA public TO butthead;
GRANT SELECT ON TABLE t TO butthead;

SET ROLE butthead;

CREATE OR REPLACE FUNCTION select_one_from_t()
RETURNS INT
AS $$
  SELECT one FROM t
$$
LANGUAGE SQL
SECURITY DEFINER -- This is the trick
;

SET ROLE beavis;

-- MASKED
SELECT * FROM t;

-- NOT MASKED
SELECT select_one_from_t();



--
-- How to protect yourself against this ?
--
-- First of all: SECURITY DEFINER is a dangerous option and should be avoided
-- whenever possible
--
-- Second: You should always restrict creating/executing functions by default.
-- This is the default behaviour with PostgreSQL 15 and further. For previous
-- versions it is recommended to REVOKE manually those privileges like this:
--
-- REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- REVOKE CREATE ON SCHEMA foo FROM PUBLIC;
-- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
-- REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA foo FROM PUBLIC;
--
-- For more details see
--
-- https://www.cybertec-postgresql.com/en/abusing-security-definer-functions
--

ROLLBACK;
