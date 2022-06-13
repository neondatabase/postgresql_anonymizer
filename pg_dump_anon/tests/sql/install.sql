BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

CREATE TABLE owner AS SELECT 'Paul' AS firstname;

SECURITY LABEL FOR anon ON COLUMN owner.firstname
  IS 'MASKED WITH VALUE ''Robert'' ';

CREATE TABLE company (
  id SERIAL PRIMARY KEY,
  name TEXT,
  vat_id TEXT UNIQUE
);

INSERT INTO company
VALUES
(952,'Shadrach', 'FR62684255667'),
(194,E'Johnny\'s Shoe Store','CHE670945644'),
(346,'Capitol Records','GB663829617823')
;

CREATE TABLE supplier (
  id SERIAL PRIMARY KEY,
  fk_company_id INT REFERENCES company(id),
  contact TEXT,
  phone TEXT,
  job_title TEXT
);

INSERT INTO supplier
VALUES
(299,194,'Johnny Ryall','597-500-569','CEO'),
(157,346,'George Clinton', '131-002-530','Sales manager')
;

CREATE SCHEMA test_pg_dump_anon;

CREATE TABLE test_pg_dump_anon.no_masks AS SELECT 1 ;

CREATE SEQUENCE test_pg_dump_anon.three
INCREMENT -1
MINVALUE 1
MAXVALUE 3
START 3
CYCLE;

CREATE SEQUENCE public.seq42;
ALTER SEQUENCE public.seq42 RESTART WITH 42;

CREATE SCHEMA "FoO";

CREATE SEQUENCE "FoO"."BuG_298";
ALTER SEQUENCE "FoO"."BuG_298" RESTART WITH 298;

COMMIT;
