BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

-- hex_to_int
SELECT anon.hex_to_int(NULL) IS NULL;
SELECT anon.hex_to_int('000000') = 0;
SELECT anon.hex_to_int('123456') = 1193046;
SELECT anon.hex_to_int('ffffff') = 16777215;

-- md5_project
SELECT anon.md5_project(NULL,NULL) IS NULL;
SELECT anon.md5_project('abcdefgh',NULL) = 0.90961080250804439235;
SELECT anon.md5_project('xxxxxxxx','yyyyy') = 0.97840040793421315755;

-- project_oid
SELECT anon.project_oid(NULL,NULL,NULL) IS NULL;
SELECT anon.project_oid('abcdefgh',NULL, 'anon.email_oid_seq') = 7277;
SELECT anon.project_oid('xxxxxxxx','yyyyy', 'anon.email_oid_seq') = 7827;


-- First Name
SELECT  anon.pseudo_first_name(NULL) IS NULL;

SELECT  anon.pseudo_first_name('bob')
      = anon.pseudo_first_name('bob');

SELECT  anon.pseudo_first_name('bob','123salt*!')
      = anon.pseudo_first_name('bob','123salt*!');

SELECT pg_typeof(anon.pseudo_first_name(NULL)) = 'TEXT'::REGTYPE;

-- Last Name
SELECT  anon.pseudo_last_name(NULL) IS NULL;
SELECT  anon.pseudo_last_name('bob','x') = anon.pseudo_last_name('bob','x');

-- Email
SELECT  anon.pseudo_email(NULL) IS NULL;
SELECT  anon.pseudo_email('bob','x') = anon.pseudo_email('bob','x');

-- City
SELECT  anon.pseudo_city(NULL) IS NULL;
SELECT  anon.pseudo_city('bob','x') = anon.pseudo_city('bob','x');

-- Region
SELECT  anon.pseudo_region(NULL) IS NULL;
SELECT  anon.pseudo_region('bob','x') = anon.pseudo_region('bob','x');

-- Country
SELECT  anon.pseudo_country(NULL) IS NULL;
SELECT  anon.pseudo_country('bob','x') = anon.pseudo_country('bob','x');

-- Company
SELECT  anon.pseudo_company(NULL) IS NULL;
SELECT  anon.pseudo_company('bob','x') = anon.pseudo_company('bob','x');

-- IBAN
SELECT  anon.pseudo_iban(NULL) IS NULL;
SELECT  anon.pseudo_iban('bob','x') = anon.pseudo_iban('bob','x');


ROLLBACK;
