--
-- G E N E R A L I Z A T I O N 
--
-- 

BEGIN;

CREATE EXTENSION anon CASCADE;

CREATE TABLE patient (
  ssn TEXT,
  firstname TEXT,
  zipcode INTEGER,
  birth DATE,
  disease TEXT
);

INSERT INTO patient 
VALUES 
    ('253-51-6170','Alice',47678,'1979-12-29','Heart Disease'),
    ('091-20-0543','Bob',46678,'1979-03-22','Heart Disease'),
    ('565-94-1926','Caroline',46678,'1971-07-22','Heart Disease'),
    ('098-24-5548','David',47905,'1997-03-04','Flu'),
    ('510-56-7882','Eleanor',47909,'1989-12-15','Heart Disease')
;

SELECT * FROM patient;

CREATE MATERIALIZED VIEW generalized_patient AS
SELECT
    '000-00-000' AS ssn,
    NULL AS firstname,
    anon.generalize_int4range(zipcode,1000) AS zipcode,
    anon.generalize_daterange(birth,'decade') AS birth,
    disease,
FROM patient;


SELECT * FROM generalized_patient;

SELECT anon.k_anonymity('patient');

ROLLBACK;