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

How to change the type of a masked column
------------------------------------------------------------------------------

When dynamic masking is activated, you are not allowed to change the datatype
on a column is there's a mask upon it.

To modify a masked column, you need to switch of temporarily the masking engine
like this:

```sql
BEGIN;
SELECT anon.stop_dynamic_masking();
ALTER TABLE people ALTER COLUMN phone TYPE VARCHAR(255);
SELECT anon.start_dynamic_masking();
COMMIT;
```


How to drop a masked table
------------------------------------------------------------------------------

The dynamic masking engine will build _masking views_ upon the masked tables.
This means that it is not possible to drop a masked table directly. You will
get an error like this :

```sql
# DROP TABLE people;
psql: ERROR:  cannot drop table people because other objects depend on it
DETAIL:  view mask.company depends on table people
```

To effectively remove the table, it is necessary to add the `CASCADE` options
so that the masking view will be dropped too:

```sql
DROP TABLE people CASCADE;
```


Limitations
------------------------------------------------------------------------------

### Only one schema

The dynamic masking system only works with one schema (by default `public`).
When you start the masking engine with `start_dynamic_masking()`, you can
specify the schema that will be masked with:

```sql
SELECT start_dynamic_masking('sales');
```

**However** in-place anonymization with `anon.anonymize()`and anonymous export
with `anon.dump()` will work fine will multiple schemas.

### Performances

Dynamic Masking is now to be very slow with some queries, especially if you
trying to join 2 tables with a masked foreign key using hashing or
pseudonymisation.
