BEGIN;

-- Sometimes it is considered as a good practice to remove the public schema
DROP SCHEMA public;

--
-- TEST 1
-- This is a weel-known case of "search_path attack"
-- An attacker could try to substitute a generic function with a malicious code
-- https://wiki.postgresql.org/wiki/A_Guide_to_CVE-2018-1058%3A_Protect_Your_Search_Path
--
CREATE SCHEMA common;
CREATE FUNCTION common.digest(TEXT,TEXT)
RETURNS BYTEA
AS $$
  CREATE ROLE bob;
  GRANT postgres TO bob;
  SELECT NULL::BYTEA;
$$
LANGUAGE SQL IMMUTABLE;

SAVEPOINT before_error;

-- This should fail
CREATE EXTENSION IF NOT EXISTS anon CASCADE SCHEMA common;

ROLLBACK TO SAVEPOINT before_error;

--
-- TEST 2
--
CREATE SCHEMA application;
CREATE EXTENSION IF NOT EXISTS anon CASCADE SCHEMA application;

SELECT anon.is_initialized() IS FALSE;

SELECT application.digest('a','sha1');

-- basic usage
SELECT anon.init();
SELECT anon.is_initialized();
SELECT anon.reset();

ROLLBACK;
