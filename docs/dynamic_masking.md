Hide sensible data from a "masked" user
===============================================================================

You can hide some data from a role by declaring this role as a "MASKED". 
Other roles will still access the original data.  

**Example**:

<!-- demo/masking.sql -->

```sql
CREATE TABLE people ( id TEXT, fistname TEXT, lastname TEXT, phone TEXT);
INSERT INTO people VALUES ('T1','Sarah', 'Conor','0609110911');
SELECT * FROM people;

=# SELECT * FROM people;
 id | fistname | lastname |   phone    
----+----------+----------+------------
 T1 | Sarah    | Conor    | 0609110911
(1 row)
```

Step 1 : Activate the dynamic masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.start_dynamic_masking();
```

Step 2 : Declare a masked user

```sql
=# CREATE ROLE skynet LOGIN;
=# SECURITY LABEL FOR anon ON ROLE skynet 
-# IS 'MASKED';
```

Step 3 : Declare the masking rules

```sql
SECURITY LABEL FOR anon ON COLUMN people.name 
IS 'MASKED WITH FUNCTION anon.random_last_name()';

SECURITY LABEL FOR anon ON COLUMN people.phone 
IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```


Step 4 : Connect with the masked user

```sql
=# \! psql peopledb -U skynet -c 'SELECT * FROM people;'
 id | fistname | lastname  |   phone    
----+----------+-----------+------------
 T1 | Sarah    | Stranahan | 06******11
(1 row)
```

Limitations
------------------------------------------------------------------------------

The dynamic masking system only works with one schema (by default `public`). 
When you start the masking engine with `start_dynamic_masking()`, you can 
specify the schema that will be masked with `SELECT start_dynamic_masking('sales');`. 

**However** in-place anonymization with `anon.anonymize()`and anonymous export 
with `anon.dump()` will work fine will multiple schemas.

