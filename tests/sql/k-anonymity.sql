
BEGIN;

CREATE TABLE patient (
  id SERIAL,
  name TEXT,
  postcode INTEGER,
  age INTEGER,
  disease TEXT
);

COPY patient
FROM STDIN CSV QUOTE AS '"' DELIMITER ' ';
1 "Alice" 47678 29 "Heart Disease"
2 "Bob" 47678 22 "Heart Disease"
3 "Caroline" 47678 27 "Heart Disease"
4 "David" 47905 43 "Flu"
5 "Eleanor" 47909 52 "Heart Disease"
6 "Frank" 47906 47 "Cancer"
7 "Geri" 47605 30 "Heart Disease"
8 "Harry" 47673 36 "Cancer"
9 "Ingrid" 47607 32 "Cancer"
\.


CREATE OR REPLACE FUNCTION generalize_int4range(
  val INTEGER,
  step INTEGER default 10
)
RETURNS INT4RANGE
AS $$
SELECT int4range(
    val / step * step,
    ((val / step)+1) * step
  );
$$
LANGUAGE SQL IMMUTABLE;

SELECT generalize_int4range(42);
SELECT generalize_int4range(42,5);
SELECT generalize_int4range(20373,1000);

SELECT min(kanonymity)
FROM (
  SELECT COUNT(*) as KAnonymity
  FROM patient
  GROUP BY name, postcode, age
) AS k
;

CREATE TEMPORARY TABLE anon_patient
AS SELECT
  NULL AS id,
  'REDACTED' AS name,
  generalize_int4range(postcode,100) AS postcode,
  generalize_int4range(age,20) AS age,
  disease
FROM patient
;

SELECT * FROM anon_patient;

SELECT min(c) AS kanonymity
FROM (
  SELECT COUNT(*) as c
  FROM anon_patient
  GROUP BY name, postcode, age
) AS k
;

SELECT min(c) AS kanonymity
FROM (
SELECT COUNT(*) as c
  FROM anon_patient
  GROUP BY name
) AS k
;


ROLLBACK;
