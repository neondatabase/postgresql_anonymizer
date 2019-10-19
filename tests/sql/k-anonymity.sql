
BEGIN;

CREATE EXTENSION anon CASCADE;

CREATE TABLE patient (
  ssn SERIAL,
  firstname TEXT,
  zipcode INTEGER,
  birth DATE,
  disease TEXT
);

COPY patient
FROM STDIN CSV QUOTE AS '"' DELIMITER ' ';
1 "Alice" 47678 "1979-12-29" "Heart Disease"
2 "Bob" 47678 "1959-03-22" "Heart Disease"
3 "Caroline" 47678 "1988-07-22" "Heart Disease"
4 "David" 47905 "1997-03-04" "Flu"
5 "Eleanor" 47909 "1999-12-15" "Heart Disease"
6 "Frank" 47906 "1968-07-04" "Cancer"
7 "Geri" 47605 "1977-10-30" "Heart Disease"
8 "Harry" 47673 "1978-06-13" "Cancer"
9 "Ingrid" 47607 "1991-12-12" "Cancer"
\.

SELECT * FROM patient;

SELECT min(kanonymity)
FROM (
  SELECT COUNT(*) as KAnonymity
  FROM patient
  GROUP BY firstname, zipcode, birth
) AS k
;

CREATE TEMPORARY TABLE anon_patient
AS SELECT
  'REDACTED' AS firstname,
  anon.generalize_int4range(zipcode,100) AS zipcode,
  anon.generalize_daterange(birth,'decade') AS birth,
  disease
FROM patient
;

SELECT * FROM anon_patient;

SELECT min(c) AS kanonymity
FROM (
  SELECT COUNT(*) as c
  FROM anon_patient
  GROUP BY firstname, zipcode, birth
) AS k
;

SELECT min(c) AS kanonymity
FROM (
SELECT COUNT(*) as c
  FROM anon_patient
  GROUP BY firstname
) AS k
;


ROLLBACK;
