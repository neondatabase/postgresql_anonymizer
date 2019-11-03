INSTALL
===============================================================================

Install on RedHat / CentOS
------------------------------------------------------------------------------

**This is the recommended way to install the extension**


0. Add the [PostgreSQL Official RPM Repo] to your system. It shouldb be something like:

```console
$ sudo yum install https://.../pgdg-redhat-repo-latest.noarch.rpm
```

[PostgreSQL Official RPM Repo]: https://yum.postgresql.org/

1. Install 

```console
$ sudo yum install postgresql12-contrib postgresql_anonymizer12
```

(Replace `12` with the major version of your PostgreSQL instance.)

2. Add 'anon' in the `shared_preload_libraries` parameter of you `postgresql.conf` file. For example:

```ini
shared_preload_libraries = 'pg_stat_statements, anon'
```

3. Restart your instance. 

Install With [PGXN](https://pgxn.org/) :
------------------------------------------------------------------------------


1. Install the extension on the server with:

```console
$ sudo apt install pgxnclient postgresql-server-dev-12
$ sudo pgxn install ddlx
$ sudo pgxn install postgresql_anonymizer
```

(Replace `12` with the major version of your PostgreSQL instance.)

2. Add 'anon' in the `shared_preload_libraries` parameter of you `postgresql.conf` file. For example:

```ini
shared_preload_libraries = 'pg_stat_statements, anon'
```

3. Restart your instance. 


**Additional notes:**

* PGXN can also be installed with `pip install pgxn`
* If you have several versions of PostgreSQL installed on your system, 
  you may have to point to the right version with the `--pg_config` 
  parameter. See [Issue #93] for more details.
* Check out the [pgxn install documentation] for more information.

[pgxn install documentation]: https://github.com/pgxn/pgxnclient/blob/master/docs/usage.rst#pgxn-install
[Issue #93]: https://gitlab.com/dalibo/postgresql_anonymizer/issues/93


Install From source
------------------------------------------------------------------------------

0. First you need to install the postgresql development libraries. On most
distribution, this is available through a package called `postgresql-devel`
or `postgresql-server-dev`.

1. Build the project like any other PostgreSQL extension:

```console
$ make extension
$ sudo make install
```

2. Add 'anon' in the `shared_preload_libraries` parameter of you `postgresql.conf` file. For example:

```ini
shared_preload_libraries = 'pg_stat_statements, anon'
```

3. Restart your instance. 


Install in the cloud
------------------------------------------------------------------------------

> **DISCLAIMER** if privacy and anonymity are a concern to you, hosting your 
> data on someone else's computer is probably not a clever idea....

Generally Database As A Service operators ( such as Amazon RDS ) do not allow 
their clients to load any extension. Instead they support only a limited subset 
of extensions, such as PostGIS or pgcrypto. You can ask them if they plan to 
support this one in the near future, but you shouldn't bet your life on it 😃

However this tool is set of plpgsql functions, which means should you be able to
install it directly without declaring an extension.

Here's a few steps to try it out:

```console
$ git clone https://gitlab.com/dalibo/postgresql_anonymizer.git
$ make standalone
$ psql ..... -f anon_standalone_PG11.sql
```

_NB_ : Replace `PG11` with the version of Postgres offered by your DBaaS operator.

In this situation, you wregistry.gitlab.com/dalibo/postgresql_anonymizerill have 
to declare the masking rules with COMMENT instead of security labels. 
See [Declaring Rules with COMMENTs] for more details.

[Declaring Rules with COMMENTs]: declare_masking_rules.md#declaring-rules-with-comments 

When you activate the masking engine, you need to disable `autoload`:

```sql
SELECT anon.start_dynamic_masking( autoload := FALSE );
```


Install with Docker
------------------------------------------------------------------------------

If you can't (or don't want to) install the PostgreSQL Anonymizer extension 
directly inside your instance, then you can use the docker image :

```console
$ docker pull registry.gitlab.com/dalibo/postgresql_anonymizer
```

You can now run the docker image like the regular [postgres docker image].

[postgres docker image]: https://hub.docker.com/_/postgres

For example:

Launch start a postgres docker container

```console
$ docker run -d --name anon -p 6543:5432 registry.gitlab.com/dalibo/postgresql_anonymizer

Connect :

```console
$ psql -h localhost -p6543 -U postgres
```

The extension is already loaded, you can use it directly:

```sql
# SELECT anon.partial_email('daamien@gmail.com');
     partial_email     
-----------------------
 da******@gm******.com
(1 row)
```


You can also treat the docker image as an "anonymizing black blox" by using a 
specific entrypoint script called `/anon.sh`. You pass the original data 
and the masking rules to the `/anon.sh` script and it will return a anonymized
dump.

Here's an example in 3 steps:

1. Dump your original data (for instance `dump.sql`)

```console
$ pg_dump [...] > dump.sql
```

2. Write your masking rules in a separate file (for instance `rules.sql`)

```sql 
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();

SECURITY LABEL FOR anon ON COLUMN people.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';
```

3. Append the masking rules at the end of the original dump file

```console
$ cat rules.sql >> dump.sql 
```

4. Pass the dump file through the docker image and receive an anonymized dump.

```console
$ ANON=docker run --rm -i registry.gitlab.com/dalibo/postgresql_anonymizer /anon.sh 
$ cat dump.sql | $ANON > anon_dump.sql
```

(this example is written on 2 lines for clarity)
