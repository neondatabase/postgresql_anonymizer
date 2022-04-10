Configuration
===============================================================================

The extension has currently a few options that be defined for the entire
instance ( inside `postgresql.conf` or with `ALTER SYSTEM`).

It is also possible and often a good idea to define them at the database level
like this:

```sql
ALTER DATABASE customers SET anon.restrict_to_trusted_schemas = on;
```

Only superuser can change the parameters below :

anon.algorithm
--------------------------------------------------------------------------------

|               |                                  |
|---------------|----------------------------------|
| Type          | Text |
| Default value | 'sha256' |
| Visible       | only to superusers |

This is the hashing method used by pseudonymizing functions. Checkout the
[pgcrypto documentation] for the list of avalaible options.

[pgcrypto documentation]: https://www.postgresql.org/docs/current/pgcrypto.htm

See `anon.salt` to learn why this parameter is a very sensitive information.

anon.maskschema
--------------------------------------------------------------------------------

|               |                                  |
|---------------|----------------------------------|
| Type          | Text |
| Default value | 'mask' |
| Visible       |  to all users |

The schema (i.e. 'namespace') where the dynamic masking views will be stored.



anon.restrict_to_trusted_schemas
--------------------------------------------------------------------------------

|               |                                  |
|---------------|----------------------------------|
| Type          | Boolean |
| Default value | off |
| Visible       |  to all users |


By enabling this parameter, masking rules must be defined using functions
located in a limited list of namespaces. By default, `pg_catalog` and `anon`
are trusted.

This improves security by preventing users from declaring their custom masking
filters.

This also means that the schema must be explicit inside the masking rules. For
instance, the rules below would fail because the schema of the lower function
is not declared.

```sql
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH FUNCTION lower(people.name) ';
```

The correct way to declare it would be :

```sql
SECURITY LABEL FOR anon ON COLUMN people.name
IS 'MASKED WITH FUNCTION pg_catalog.lower(people.name) ';
```

This parameter is kept to `off` in the current version to maintain backward
compatibility but we highly encourage users to switch to `on` when possible.
In the forthcoming version, we may define `on` as the default behaviour.




anon.salt
--------------------------------------------------------------------------------

|               |                                  |
|---------------|----------------------------------|
| Type          | Text |
| Default value | (empty) |
| Visible       | only to superusers |

This is the salt used by pseudonymizing functions. It is very important to
define a custom salt for each database like this:

```sql
ALTER DATABASE foo SET anon.salt = 'This_Is_A_Very_Secret_Salt';
```

If a masked user can read the salt, he/she can run a brute force attack to
retrieve the original data based on the 3 elements:

* The pseudonymized data
* The hashing algorithm (see `anon.algorithm`)
* The salt

The GDPR considered that the salt and the name of the hashing algorithm should
be protected with the same level of security that the data itself. This is
why you should store the salt directly within the database with `ALTER DATABASE`.



anon.sourceshema
--------------------------------------------------------------------------------

|               |                                  |
|---------------|----------------------------------|
| Type          | Text |
| Default value | 'public' |
| Visible       | to all users |

The schema (i.e. 'namespace') where the tables are masked by the dynamic masking
engine.

Change this value before starting dynamic masking.

```sql
ALTER DATABASE foo SET anon.sourceschema TO 'my_app';
```

Then reconnect so that the change takes effect and start the engine.

```sql
SELECT start_dynamic_masking();
```


