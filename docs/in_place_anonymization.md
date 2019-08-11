Permanently remove sensitive data
===============================================================================

You can permanetly remove the Personal information from a database 
with `anon.anymize_database()`.

This will destroy the original data. Use with care.


Let's use a basic example :

```sql

CREATE TABLE customer(
	id SERIAL,
	full_name TEXT,
	birth DATE,
	employer TEXT,
	zipcode TEXT,
	fk_shop INTEGER
);

INSERT INTO customer
VALUES 
(911,'Chuck Norris','1940/03/10','Texas Rangers', '75001',12),
(312,'David Hasselhoff','1952/07/17','Baywatch', '90001',423)
;

SELECT * FROM customer;

 id  |   full_name      |   birth    |    employer   | zipcode | fk_shop
-----+------------------+------------+---------------+---------+---------
 911 | Chuck Norris     | 1940-03-10 | Texas Rangers | 75001   | 12
 112 | David Hasselhoff | 1952-07-17 | Baywatch      | 90001   | 423

```

Step 1: Load the extension :

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();
``` 

Step 2: Declare the masking rules 

```sql
COMMENT ON COLUMN customer.full_name 
IS 'MASKED WITH FUNCTION anon.fake_first_name() || '' '' || anon.fake_last_name()';

COMMENT ON COLUMN customer.employer
IS 'MASKED WITH FUNCTION anon.fake_company()';

COMMENT ON COLUMN customer.zipcode
IS 'MASKED WITH FUNCTION anon.random_zip()';
```


Step 3: Replace authentic data in the masked columns :

```sql
SELECT anon.anonymize_database();

SELECT * FROM customer;

 id  |  full_name  |   birth    |      employer       | zipcode | fk_shop 
-----+-------------+------------+---------------------+---------+---------
 911 | jesse Kosel | 1940-03-10 | Marigold Properties | 62172   |      12
 312 | leolin Bose | 1952-07-17 | Inventure           | 20026   |     423

```



You can also use `anonymize_table()` and `anonymize_column()` to remove data from
a subset of the database :

```sql
SELECT anon.anonymize_table('customer');
SELECT anon.anonymize_column('customer','zipcode');
```

