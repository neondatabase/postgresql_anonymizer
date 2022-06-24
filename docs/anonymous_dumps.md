Anonymous Dumps
===============================================================================

Due to the core design of this extension, you cannot use `pg_dump` with a masked
user. If you want to export the entire database with the anonymized data, you
must use the `pg_dump_anon.sh` command.


pg_dump_anon.sh
------------------------------------------------------------------------------

The `pg_dump_anon.sh` wrapper is designed to export the masked data. You can use
it like the regular `pg_dump` command.

```bash
pg_dump_anon.sh -h localhost -U bob mydb > anonymous_dump.sql
```

It uses the same connections parameters that `pg_dump` :

```bash
$ pg_dump_anon.sh --help

Usage: pg_dump_anon.sh [OPTION]... [DBNAME]

General options:
  -f, --file=FILENAME           output file
  --help                        display this message

Options controlling the output content:
  -n, --schema=PATTERN          dump the specified schema(s) only
  -N, --exclude-schema=PATTERN  do NOT dump the specified schema(s)
  -t, --table=PATTERN           dump the specified table(s) only
  -T, --exclude-table=PATTERN   do NOT dump the specified table(s)
  --exclude-table-data=PATTERN  do NOT dump data for the specified table(s)

Connection options:
  -d, --dbname=DBNAME           database to dump
  -h, --host=HOSTNAME           database server host or socket directory
  -p, --port=PORT               database server port number
  -U, --username=NAME           connect as specified database user
  -w, --no-password             never prompt for password
  -W, --password                force password prompt (should happen automatically)

If no database name is supplied, then the PGDATABASE environment
variable value is used.

```


* The [PostgreSQL environment variables] ($PGHOST, PGUSER, etc.) are supported.
* The [.pgpass] file is also supported.
* The `plain` format is the only supported format. The other formats (`custom`, `dir`
  and `tar`) are not supported

[PostgreSQL environment variables]: https://www.postgresql.org/docs/current/libpq-envars.html
[.pgpass]: https://www.postgresql.org/docs/current/libpq-pgpass.html


Consistent Backups
------------------------------------------------------------------------------

> IMPORTANT: due to its internal design, `pg_dump_anon.sh` MAY NOT produce a
> consistent backup.

Especially if you are running `DML` or `DDL` commands during the anonymous export,
you will end up with a broken dump file.

If backup consistency is required, you can simply use [static masking] and then
export the data with `pg_dump`. Here's a practical example of this approach:

https://gitlab.com/dalibo/postgresql_anonymizer/-/issues/266#note_817261637

[static masking]: static_masking.md


TIP: Avoid multiple password prompts
------------------------------------------------------------------------------

If you don't provide the connection password to `pg_dump_anon.sh` using the
`--password` option, you may have to type the password multiple times.To
avoid this, you can either [define the $PGPASS variable] or place your
password in a [.pgpass] file.

[define the $PGPASS variable]: https://www.postgresql.org/docs/current/libpq-envars.html


DEPRECATED: DO NOT USE anon.dump()
------------------------------------------------------------------------------

The version 0.3 of PostgreSQL Anonymizer introduced a function called
`anon.dump()`. This function is extremely slow. Since version 0.6, it has
been deprecated and it is not supported anymore.

The function is kept as is for backward compatibility. It will probably be
removed from one of the forthcoming versions.

Again: do not use this function ! To dump the masked data, use the
`pg_dump_anon.sh` command line tool as described above.
