Hide sensitive data from a "masked" user
===============================================================================

You can hide some data from a role by declaring this role as "MASKED".

Other roles will still access the original data.

**Example**:

<!-- demo/masking.sql -->

```sql
CREATE TABLE people ( id TEXT, firstname TEXT, lastname TEXT, phone TEXT);
INSERT INTO people VALUES ('T1','Sarah', 'Conor','0609110911');
SELECT * FROM people;

=# SELECT * FROM people;
 id | firstname | lastname |   phone
----+-----------+----------+------------
 T1 | Sarah     | Conor    | 0609110911
(1 row)
```

Step 1 : Activate the dynamic masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# ALTER DATABASE foo SET anon.transparent_dynamic_masking TO true;
```

Step 2 : Declare the masking rules

```sql
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH FUNCTION anon.dummy_last_name()';

SECURITY LABEL FOR anon ON COLUMN people.phone
IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

Step 3 : Declare a masked user with read access

```sql
=# CREATE ROLE skynet LOGIN;
=# SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';
```

```sql
GRANT pg_read_all_data to skynet;
```

**NOTE:** If you are running PostgreSQL 13 or if you want a more
fine-grained access policy you can grant access more precisely, for instance:

```sql
GRANT USAGE ON SCHEMA public TO skynet;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO skynet;
-- etc.
```




Step 4 : Connect with the masked user

```sql
=# \c - skynet
=> SELECT * FROM people;
 id | firstname | lastname  |   phone
----+-----------+-----------+------------
 T1 | Sarah     | Stranahan | 06******11
(1 row)
```

How to unmask a role
------------------------------------------------------------------------------

Simply remove the security label like this:

```sql
SECURITY LABEL FOR anon ON ROLE bob IS NULL;
```


Legacy Dynamic Masking
------------------------------------------------------------------------------

In version 1.x, the dynamic masking method was done using a method named
[Legacy Dynamic Masking]. Although this former method is still functional, it
will be deprecated in version 3.

[Transparent Dynamic Masking] and [Legacy Dynamic Masking] cannot work at the
same time. If you upgraded from version 1, be sure to disable
[Legacy Dynamic Masking] with:

```sql
SELECT anon.stop_legacy_dynamic_masking();
```

[Transparent Dynamic Masking]: dynamic_masking.md

[Legacy Dynamic Masking]: legacy_dynamic_masking.md
