
BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- INIT

SELECT anon.load();


CREATE TABLE customer (
  id SERIAL,
  firstname TEXT,
  last_name TEXT,
  "CreditCard" TEXT
);

CREATE TABLE vendor (
  employee_id INTEGER UNIQUE,
  "Firstname" TEXT,
  lastname TEXT,
  phone_number TEXT,
  birth DATE
);


SELECT anon.detect();

SELECT * FROM anon.detect('fr_FR');


ROLLBACK;
