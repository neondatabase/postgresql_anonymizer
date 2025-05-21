Anonymous Dumps
===============================================================================


![PostgreSQL Anonymous Dumps](images/anon-Dump.drawio.png)

Transparent Anonymous Dumps
------------------------------------------------------------------------------

To export the anonymized data from a database, follow these 3 steps:

### 1. Create a masked user

```sql
CREATE ROLE anon_dumper LOGIN PASSWORD 'x';
ALTER ROLE anon_dumper SET anon.transparent_dynamic_masking = True;
SECURITY LABEL FOR anon ON ROLE anon_dumper IS 'MASKED';
```

__NOTE:__ You can replace the name `anon_dumper` by another name.


### 2. Grant read access to that masked user

```sql
GRANT pg_read_all_data to anon_dumper;
```

__NOTE:__ If you are running PostgreSQL 13 or if you want a more fine-grained
access policy you can grant access more precisely, for instance:


```sql
GRANT USAGE ON SCHEMA public TO anon_dumper;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon_dumper;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO anon_dumper;

GRANT USAGE ON SCHEMA foo TO anon_dumper;
GRANT SELECT ON ALL TABLES IN SCHEMA foo TO anon_dumper;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA foo TO anon_dumper;
```


### 3. Launch pg_dump with the masked user

Now to export the anonymous data from a database named `foo`, let's use
`pg_dump`:

```bash
pg_dump foo \
        --user anon_dumper \
        --no-security-labels \
        --exclude-extension="anon" \
        --file=foo_anonymized.sql
```

__NOTES:__

* linebreaks are here for readability

* `--no-security-labels` will remove the masking rules from the anonymous dump.
  This is really important because masked users should not have access to the
  masking policy.

* `--exclude-extension` is only available with `pg_dump 17` and later.
  As an alternative you can use `--extension plpgsql`.

* `--format=custom` is supported


Anonymizing an SQL file
-----------------------------------------------------------------------------

![](images/anon-Files.drawio.png)

[Install with docker]: INSTALL.md#install-with-docker

> In previous versions of the documentation, this method was also called
> « anonymizing black box ».

You can also apply masking rules directly on a database backup file !

The PostgreSQL Anonymizer docker image contains a specific entrypoint script
called `/dump.sh`. You pass the original data and the masking rules to
to that `/dump.sh` script and it will return an anonymized dump.

Here's an example in 4 steps:

_Step 1:_  Dump your original data (for instance `dump.sql`)

```console
pg_dump --format=plain [...] my_db > dump.sql
```

Note this method only works with plain sql format (`-Fp`). You **cannot**
use the custom format (`-Fc`) and the directory format (`-Fd`) here.

If you want to maintain the owners and grants, you need export them with
`pg_dumpall --roles-only` like this:

```console
(pg_dumpall -Fp [...] --roles-only && pg_dump -Fp [...] my_db ) > dump.sql
```

_Step 2:_  Write your masking rules in a separate file (for instance `rules.sql`)

```sql

SECURITY LABEL FOR anon ON COLUMN people.lastname
IS 'MASKED WITH FUNCTION anon.dummy_last_name()';

-- etc.
```

_Step 3:_  Pass the dump and the rules through the docker image and receive an
anonymized dump !

```console
IMG=registry.gitlab.com/dalibo/postgresql_anonymizer
ANON="docker run --rm -i $IMG /dump.sh"
cat dump.sql rules.sql | $ANON > anon_dump.sql
```

(this last step is written on 3 lines for clarity)

_NB:_ You can also gather _step 1_ and _step 3_ in a single command:

```console
(pg_dumpall --roles-only && pg_dump my_db && cat rules.sql) | $ANON > anon_dump.sql
```

__NOTES:__

You can use most the [pg_dump output options] with the `/dump.sh` script,
for instance:

```console
cat dump.sql rules.sql | $ANON --data-only --inserts > anon_dump.sql
```



[pg_dump output options]: https://www.postgresql.org/docs/current/app-pgdump.html#PG-DUMP-OPTIONS


DEPRECATED : pg_dump_anon.sh and pg_dump_anon
------------------------------------------------------------------------------

In version 0.x, the anonymous dumps were done with a shell script named
`pg_dump_anon.sh`. In version 1.x it was done with a golang script named
`pg_dump_anon`. **Both commands are now deprecated.**

However `pg_dump_anon` is kept for backward compatibility. If you are still
using `pg_dump_anon`, you should switch to the `pg_dump` method described above
as soon as possible.
