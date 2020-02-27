BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

-- First Name
SELECT  anon.pseudo_first_name('bob')
      = anon.pseudo_first_name('bob');

SELECT  anon.pseudo_first_name('bob','123salt*!')
      = anon.pseudo_first_name('bob','123salt*!');

SELECT anon.pseudo_first_name(NULL) IS NULL;

SELECT pg_typeof(anon.pseudo_first_name(NULL)) = 'TEXT'::REGTYPE;

ROLLBACK;
