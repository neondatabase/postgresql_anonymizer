Generalization
===============================================================================


Reducing the accuracy of sensible data
--------------------------------------------------------------------------------

TODO

Example
--------------------------------------------------------------------------------

Here's a basic table containing medical data:

```sql
# SELECT * FROM patient;
     ssn     | firstname | zipcode |   birth    |    disease    
-------------+-----------+---------+------------+---------------
 253-51-6170 | Alice     |   47678 | 1979-12-29 | Heart Disease
 091-20-0543 | Bob       |   46678 | 1979-03-22 | Heart Disease
 565-94-1926 | Caroline  |   46678 | 1971-07-22 | Heart Disease
 098-24-5548 | David     |   47905 | 1997-03-04 | Flu
 510-56-7882 | Eleanor   |   47909 | 1989-12-15 | Heart Disease
```

We want the anonymized data to remain **true** because it will be
used for statistics. We can build a view upon this table to remove 
useless columns and generalized the indirect identifiers :

```sql
CREATE VIEW generalized_patient AS
SELECT
    'REDACTED'::TEXT AS firstname,
    anon.generalize_int4range(zipcode,1000) AS zipcode,
    anon.generalize_daterange(birth,'decade') AS birth,
    disease,
FROM patient;
```

This will give us a less accurate view of the data:

```sql
# SELECT * FROM generalized_patient;
 firstname |    zipcode    |          birth          |    disease    
-----------+---------------+-------------------------+---------------
 REDACTED  | [47000,48000) | [1970-01-01,1980-01-01) | Heart Disease
 REDACTED  | [46000,47000) | [1970-01-01,1980-01-01) | Heart Disease
 REDACTED  | [46000,47000) | [1970-01-01,1980-01-01) | Heart Disease
 REDACTED  | [47000,48000) | [1990-01-01,2000-01-01) | Flu
 REDACTED  | [47000,48000) | [1980-01-01,1990-01-01) | Heart Disease
 ```

Generalization Functions
--------------------------------------------------------------------------------

TODO

Limitation
--------------------------------------------------------------------------------

### Singling out and extreme values

TODO 

### Generalization is not compatible with dynamic masking

TODO 


K-Anonymity
--------------------------------------------------------------------------------

```sql
SECURITY LABEL FOR anon ON COLUMN patient.firstname IS 'INDIRECT IDENTIFIER';
SECURITY LABEL FOR anon ON COLUMN patient.zipcode IS 'INDIRECT IDENTIFIER';
SECURITY LABEL FOR anon ON COLUMN patient.birth IS 'INDIRECT IDENTIFIER';
```

```sql
SELECT anon.k_anonymity('patient')
```

TODO 


Links
--------------------------------------------------------------------------------

TODO
