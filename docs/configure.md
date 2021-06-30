Configuration
===============================================================================

The extension has currently a few options that be defined for the entire
instance ( inside `postgresql.conf` or with `ALTER SYSTEM`). It is also possible
to define them at the database level like this

```sql
ALTER DATABASE customers SET anon.restrict_to_trusted_schemas = on;
```

Only superuser can change the parameters below :


anon.restrict_to_trusted_schemas
--------------------------------------------------------------------------------

> Type : Boolean
> Default Value : off

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



