
![PostgreSQL Anonymizer](https://gitlab.com/dalibo/postgresql_anonymizer/raw/master/images/png_RVB/PostgreSQL-Anonymizer_H_couleur.png)


Anonymization & Data Masking for PostgreSQL
===============================================================================

`postgresql_anonymizer` is an extension to mask or replace
[personally identifiable information] (PII) or commercially sensitive data from
a PostgreSQL database.

The projet is aiming toward a **declarative approach** of anonymization. This
means we're trying to extend PostgreSQL Data Definition Language (DDL) in
order to specify the anonymization strategy inside the table definition itself.

The extension can be used to put dynamic masks on certain users or permanently
modify sensitive data. Various masking techniques are available : randomization,
partial scrambling or custom rules.

Read the [Concepts] section for more details and [NEWS.md] for information
about the latest version.

[NEWS.md]: NEWS.md
[INSTALL.md]: INSTALL.md
[Concepts]: #Concepts
[personally identifiable information]: https://en.wikipedia.org/wiki/Personally_identifiable_information


Warning
------------------------------------------------------------------------------

*This is projet is at an early stage of development and should used carefully.*

We need your feedback and ideas ! Let us know what you think of this tool,how it
fits your needs and what features are missing.

You can either [open an issue] or send a message at <contact@dalibo.com>.

[open an issue]: https://gitlab.com/dalibo/postgresql_anonymizer/issues

Example
------------------------------------------------------------------------------

```sql
=# SELECT * FROM people;
  id  |      name      |   phone
------+----------------+------------
 T800 | Schwarzenegger | 0609110911
(1 row)
```

STEP 1 : Activate the masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.mask_init();
```

STEP 2 : Declare a masked user

```sql
=# CREATE ROLE skynet LOGIN;
=# COMMENT ON ROLE skynet IS 'MASKED';
```

STEP 3 : Declare the masking rules

```sql
=# COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.fake_last_name()';

=# COMMENT ON COLUMN people.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

STEP 4 : Connect with the masked user

```sql
=# \! psql test -U skynet -c 'SELECT * FROM people;'
  id  |   name   |   phone
------+----------+------------
 T800 | Nunziata | 06******11
(1 row)
```

