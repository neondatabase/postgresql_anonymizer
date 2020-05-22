INSTALL
===============================================================================

The installation process is composed of 2 basic steps: 

1. First, install the extension on the PostgreSQL instance
2. Then, load the extension in the instance

There are multiple ways to install the extension :

* [Install on RedHat / CentOS]
* [Install with PGXN]
* [Install from source]
* [Install in the cloud]
* [Install with docker]
* [Install as a block box]
* [Install on MacOS]

In the examples below, we load the extension using `session_preload_librairies` 
but there are also multiple ways to load it. See [Load the extension]
for more details.

[Install on RedHat / CentOS]: #install-on-redhat-centos
[Install with PGXN]: #install-with-pgxn
[Install from source]: #install-from-source
[Install in the cloud]: #install-in-the-cloud
[Install with docker]: #install-with-docker
[Install as a block box]: #install-as-a-black-box
[Install on MacOS]: #install-on-macos
[Load the extension]: #load-the-extension


Install on RedHat / CentOS
------------------------------------------------------------------------------

**This is the recommended way to install the extension**


_Step 0:_ Add the [PostgreSQL Official RPM Repo] to your system. It shouldb be 
something like:

```console
$ sudo yum install https://.../pgdg-redhat-repo-latest.noarch.rpm
```

[PostgreSQL Official RPM Repo]: https://yum.postgresql.org/


_Step 1:_ Install 

```console
$ sudo yum install postgresql_anonymizer12
```

(Replace `12` with the major version of your PostgreSQL instance.)

_Step 2:_  Add the extension to the preloaded librairies of your database.
(If you already loading extensions that way, just add it the list)

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

_Step 3:_  Declare the extension and load the anonymization data

```sql
CREATE EXTENSION anon CASCADE;
SELECT anon.load();
```

All new connections to the database can now use the extension.


Install With [PGXN](https://pgxn.org/) :
------------------------------------------------------------------------------


_Step 1:_  Install the extension on the server with:

```console
$ sudo apt install pgxnclient postgresql-server-dev-12 
$ sudo pgxn install postgresql_anonymizer
```

(Replace `12` with the major version of your PostgreSQL instance.)

_Step 2:_  Add the extension to the preloaded librairies of your database.
(If you already loading extensions that way, just add it the list)

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

_Step 3:_  Declare the extension and load the anonymization data

```sql
CREATE EXTENSION anon CASCADE;
SELECT anon.load();
```

All new connections to the database can now use the extension.


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

_Step 0:_ First you need to install the postgresql development libraries. On most
distribution, this is available through a package called `postgresql-devel`
or `postgresql-server-dev`.

_Step 1:_  Build the project like any other PostgreSQL extension:
   
```console
$ make extension
$ sudo make install
```

_Step 2:_  Add the extension to the preloaded librairies of your database.
(If you already loading extensions that way, just add it the list)

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

_Step 3:_  Declare the extension and load the anonymization data

```sql
CREATE EXTENSION anon CASCADE;
SELECT anon.load();
```

All new connections to the database can now use the extension.


Install in the cloud
------------------------------------------------------------------------------

> **DISCLAIMER** if privacy and anonymity are a concern to you, hosting your 
> data on someone else's computer is probably not a clever idea....

Generally Database As A Service operators ( such as Amazon RDS ) do not allow 
their clients to load any extension. Instead they support only a limited subset 
of extensions, such as PostGIS or pgcrypto. You can ask them if they plan to 
support this one in the near future, but you shouldn't bet your life on it 😃

However this tool is set of `plpgsql` functions, which means should you be able 
to install it directly without declaring an extension.

Here's a few steps to try it out:

```console
$ git clone https://gitlab.com/dalibo/postgresql_anonymizer.git
$ make anon_standalone.sql
$ psql ..... -f anon_standalone.sql
```

In this situation, you will have to declare the masking rules with `COMMENT` instead 
of security labels. See [Declaring Rules with COMMENTs] for more details.

[Declaring Rules with COMMENTs]: declare_masking_rules.md#declaring-rules-with-comments 

### Special Notes about Dynamic Masking and DBaaS providers

Here's a few remarks on how to make the [Dynamic Masking] work on a cloud 
PostgreSQL service :


First, when you activate the masking engine, you need also to disable `autoload`
(because the data was already loaded by the `anon_standalone.sql` script):

```sql
SELECT anon.start_dynamic_masking( autoload := FALSE );
```

Second, the [Dynamic Masking] engine will put [Event Triggers] on the tables. 
In order to do that, you must be allowed to create event triggers, which means 
either being a superuser or having a role with similar privileges.

Creating [Event Triggers] may or may be not be supported by your cloud 
operator. For instance, [Amazon RDS supports event triggers] since version 9.4
while [Alibaba Cloud does not allow them]. You should refer to your provider's
documentation or its customer service to check if this feature is available.


[Dynamic Masking]: dynamic_masking.md
[Event Triggers]: https://www.postgresql.org/docs/current/event-triggers.html
[Amazon RDS supports event triggers]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts.General.FeatureSupport.EventTriggers
[Alibaba Cloud does not allow them]: https://gitlab.com/dalibo/postgresql_anonymizer/-/issues/126



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
```

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

Install as a "Black Box"
------------------------------------------------------------------------------


You can also treat the docker image as an "anonymizing black box" by using a 
specific entrypoint script called `/anon.sh`. You pass the original data 
and the masking rules to the `/anon.sh` script and it will return a anonymized
dump.

Here's an example in 4 steps:

_Step 1:_  Dump your original data (for instance `dump.sql`)

```console
$ pg_dump [...] my_db > dump.sql
```

If you want to maintain the owners and grants, you need export them with 
`pg_dumpall --roles-only` like this:

```console
$ (pg_dumpall [...] --roles-only && pg_dump [...] my_db ) > dump.sql
```


_Step 2:_  Write your masking rules in a separate file (for instance `rules.sql`)

```sql 
SELECT pg_catalog.set_config('search_path', 'public', false); 

CREATE EXTENSION anon CASCADE;
SELECT anon.load();

SECURITY LABEL FOR anon ON COLUMN people.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';

etc.
```

_Step 3:_  Pass the dump and the rules through the docker image and receive an 
anonymized dump !

```console
$ IMG=registry.gitlab.com/dalibo/postgresql_anonymizer
$ ANON="docker run --rm -i $IMG /anon.sh" 
$ cat dump.sql rules.sql | $ANON > anon_dump.sql
```

(this last step is written on 3 lines for clarity)

_NB:_ You can also gather _step 1_ and _step 3_ in a single command:

```console
$ (pg_dumpall --roles-only && pg_dump my_db) | cat - rules.sql | $ANON > anon_dump.sql
```


Install on MacOS
------------------------------------------------------------------------------

Although the extension is not officially supported on MacOS systems, it should
be possible to build the extension with the following lines:

```console
$ export C_INCLUDE_PATH="$(xcrun --show-sdk-path)/usr/include" 
$ make extension
$ make install
```


Load the extension
------------------------------------------------------------------------------

Here's some additional notes about how you can load the extension:

### 1- Load only for one database

You can load the extension exclusively into a specific database like this: 

```sql
ALTER DATABASE mydatabase SET session_preload_libraries='anon'
```

Then quit your current session and open a new one.

It has several benefits:  

* First, it will be dumped by `pg_dump` with the`-C` option, so the database 
  dump will be self efficient. 
  
* Second, it is propagated to a standby instance by streaming replication. 
  Which means you can use the anonymization functions on a read-only clone 
  of the database (provided the extension is installed on the standby instance)
  
### 2- Load for the instance

You can load the extension with the `shared_preload_libraries` parameter.

```sql
ALTER SYSTEM SET shared_preload_libraries = 'anon'"
```

Then restart the PostgreSQL instance.


### 3- Load on the fly

For a one-time usage, You can the [LOAD] command

```sql
LOAD '/usr/lib/postgresql/12/lib/anon.so';
```

You can read the [Shared Library Preloading] section of the PostgreSQL documentation
for more details.

[LOAD]: https://www.postgresql.org/docs/current/sql-load.html
[Shared Library Preloading]:https://www.postgresql.org/docs/current/runtime-config-client.html#RUNTIME-CONFIG-CLIENT-PRELOAD

