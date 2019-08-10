Hide sensible data from a "masked" user
===============================================================================

You can hide some data from a role by declaring this role as a "MASKED". 
Other roles will still access the original data.  

**Example**:

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

3. Activate the masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.start_dynamic_masking();
```

Declare a masked user

```sql
=# CREATE ROLE skynet LOGIN;
=# COMMENT ON ROLE skynet IS 'MASKED';
```

Declare the masking rules

```sql
=# COMMENT ON COLUMN people.lastname IS 'MASKED WITH FUNCTION anon.fake_last_name()';

=# COMMENT ON COLUMN people.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

Connect with the masked user

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

