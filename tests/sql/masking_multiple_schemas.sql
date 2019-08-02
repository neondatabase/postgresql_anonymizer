BEGIN;

CREATE SCHEMA sales;
CREATE SCHEMA "HR";
CREATE SCHEMA marketing;

CREATE TABLE sales.staff(
    staff_id SERIAL PRIMARY KEY,
    firstname VARCHAR(45) NOT NULL,
    lastname VARCHAR(45) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);
COMMENT ON COLUMN sales.staff.lastname IS 'MASKED WITH FUNCTION anon.random_last_name()';

CREATE TABLE "HR".staff(
    staff_id SERIAL PRIMARY KEY,
    firstname VARCHAR(45) NOT NULL,
    lastname VARCHAR(45) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);
COMMENT ON COLUMN "HR".staff.lastname IS 'MASKED WITH FUNCTION anon.random_last_name()';

CREATE TABLE marketing.staff(
    staff_id SERIAL PRIMARY KEY,
    firstname VARCHAR(45) NOT NULL,
    lastname VARCHAR(45) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);
COMMENT ON COLUMN marketing.staff.lastname IS 'MASKED WITH FUNCTION anon.random_last_name()';

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.mask_init();

ROLLBACK;


