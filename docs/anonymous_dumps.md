Anonymous Dumps
===============================================================================

Due to the core design of this extension, you cannot use `pg_dump` with a masked
user. If you want to export the entire database with the anonymized data, you
must use the `pg_dump_anon` command.

pg_dump_anon
------------------------------------------------------------------------------

The `pg_dump_anon` command support most of the options of the regular [pg_dump]
command. The [PostgreSQL environment variables] ($PGHOST, PGUSER, etc.) and
the [.pgpass] file are also supported.

[PostgreSQL environment variables]: https://www.postgresql.org/docs/current/libpq-envars.html
[.pgpass]: https://www.postgresql.org/docs/current/libpq-pgpass.html


Example
------------------------------------------------------------------------------

A user named `bob` can export an anonymous dump of the `app` database like
this:

```bash
pg_dump_anon -h localhost -U bob --password --file=anonymous_dump.sql app
```

**WARNING**: The name of the database must be the last parameter.

For more details about the supported options, simply type `pg_dump_anon --help`



Install
------------------------------------------------------------------------------

### With Go

```console
go install gitlab.com/dalibo/postgresql_anonymizer/pg_dump_anon
```

### With docker

If you do not want to instal Go on your production servers, you can fetch the
binary with:

```console
docker run --rm -v "$PWD":/go/bin golang go get gitlab.com/dalibo/postgresql_anonymizer/pg_dump_anon
sudo install pg_dump_anon $(pg_config --bindir)
```



Limitations
------------------------------------------------------------------------------

* The user password is asked automatically. This means you must either add
  the `--password` option to define it interactively or declare it in the
  [PGPASSWORD] variable or put it inside the [.pgpass] file ( however on
  Windows,the [PGPASSFILE] variable must be specified explicitly)

* The `plain` format is the only supported format. The other formats (`custom`,
  `dir` and `tar`) are not supported


[PGPASSWORD]: https://www.postgresql.org/docs/current/libpq-envars.html
[PGPASSFILE]: https://www.postgresql.org/docs/current/libpq-envars.html


Obsolete: pg_dump_anon.sh
------------------------------------------------------------------------------

Before version 1.0, `pg_dump_anon` was a bash script. This script was nice and
simple, however under certain conditions the backup were not consistent. See
[issue #266] for more details.

[issue #266]: https://gitlab.com/dalibo/postgresql_anonymizer/-/issues/266

This script is now renamed to `pg_dump_anon.sh` and it is still available for
backwards compatibility. But it will be deprecated in version 2.0.


