INSTALL
===============================================================================

The installation process is composed of 4 basic steps:

* Step 1: **Deploy** the extension into the host server
* Step 2: **Load** the extension in the PostgreSQL instance
* Step 3: **Create** and **Initialize** the extension inside the database

There are multiple ways to install the extension :

* [Install on RedHat / Rocky Linux / Alma Linux]
* [Install on Debian / Ubuntu]
* [Install with PGXN]
* [Install from source]
* [Install with docker]
* [Install as a black box]
* [Install on MacOS]
* [Install on Windows]
* [Install in the cloud]
* [Uninstall]

In the examples below, we load the extension (step2) using a parameter called
`session_preload_libraries` but there are other ways to load it.
See [Load the extension] for more details.

If you're having any problem, check the [Troubleshooting] section.

[Install on RedHat / Rocky Linux / Alma Linux]: #install-on-redhat-rocky-linux-alma-linux
[Install on Debian / Ubuntu]: #install-on-debian-ubuntu
[Install with PGXN]: #install-with-pgxn
[Install from source]: #install-from-source
[Install with docker]: #install-with-docker
[Install as a black box]: #install-as-a-black-box
[Install on MacOS]: #install-on-macos
[Install on Windows]: #install-on-windows
[Install in the cloud]: #install-in-the-cloud
[Uninstall]: #uninstall
[Load the extension]: #addendum-alternative-ways-to-load-the-extension
[Troubleshooting]: #addendum-troubleshooting

Choose your version : `Stable` or `Latest` ?
------------------------------------------------------------------------------

This extension is available in two versions :

* `stable` is recommended for production
* `latest` is useful if you want to test new features




Install on RedHat / Rocky Linux / Alma Linux
------------------------------------------------------------------------------

!!! warning New RPM repository !

    DO NOT use the package provided by the PGDG RPM repository.
    It is obsolete.

_Step 0:_ Add the [DaLibo Labs RPM repository] to your system.

```console
sudo dnf install https://yum.dalibo.org/labs/dalibo-labs-4-1.noarch.rpm
```

[Dalibo Labs RPM repository]: https://yum.dalibo.org/labs/

Alternatively you can download the `latest` version from the
[Gitlab Package Registry].

_Step 1:_ Deploy

```console
sudo yum install postgresql_anonymizer_16
```

(Replace `16` with the major version of your PostgreSQL instance.)

_Step 2:_  Load the extension.

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

(If you're already loading extensions that way, just add `anon` the current list)

> The setting will be applied for the next sessions,
> i.e. **You need to reconnect to the database for the change to visible**



_Step 3:_  Close your session and open a new one. Create the extension.

```sql
CREATE EXTENSION anon;
SELECT anon.init();
```

All new connections to the database can now use the extension.

Install on Debian / Ubuntu
------------------------------------------------------------------------------

> This is the recommended way to install the `stable` version

_Step 0:_ Add the [DaLibo Labs DEB Repo] to your system.

```console
apt install curl lsb-release
echo deb http://apt.dalibo.org/labs $(lsb_release -cs)-dalibo main > /etc/apt/sources.list.d/dalibo-labs.list
curl -fsSL -o /etc/apt/trusted.gpg.d/dalibo-labs.gpg https://apt.dalibo.org/labs/debian-dalibo.gpg
apt update
```

[Dalibo Labs DEB Repo]: https://apt.dalibo.org/labs/

Alternatively you can download the `latest` version from the
[Gitlab Package Registry].

[Gitlab Package Registry]: https://gitlab.com/dalibo/postgresql_anonymizer/-/packages

_Step 1:_ Deploy

```console
sudo apt install postgresql_anonymizer_16
```

(Replace `16` with the major version of your PostgreSQL instance.)

_Step 2:_  Load the extension.

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

(If you're already loading extensions that way, just add `anon` the current list)

> The setting will be applied for the next sessions,
> i.e. **You need to reconnect to the database for the change to visible**

_Step 3:_  Close your session and open a new one. Create the extension.

```sql
CREATE EXTENSION anon;
SELECT anon.init();
```

All new connections to the database can now use the extension.

Install With [PGXN](https://pgxn.org/) :
------------------------------------------------------------------------------

> This method will install the `stable` extension


_Step 1:_  Deploy the extension into the host server with:

```console
sudo apt install pgxnclient postgresql-server-dev-12
sudo pgxn install postgresql_anonymizer
```

(Replace `12` with the major version of your PostgreSQL instance.)

_Step 2:_  Load the extension.

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

(If you're already loading extensions that way, just add `anon` the current list)

_Step 3:_  Close your session and open a new one. Create the extension.

```sql
CREATE EXTENSION anon;
SELECT anon.init();
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

[PGRX System Requirements]: https://github.com/pgcentralfoundation/pgrx?tab=readme-ov-file#system-requirements

> This is the recommended way to install the `latest` extension

**Important**: Building the extension requires a full Rust development
environment. It is not recommended to build it on a production server.

Before anything else, you need to install the [PGRX System Requirements].

_Step 0:_ Download the source from the
[official repository on Gitlab](https://gitlab.com/dalibo/postgresql_anonymizer/),
either the archive of the [latest release](https://gitlab.com/dalibo/postgresql_anonymizer/-/releases),
or clone the `latest` branch:

```console
git clone https://gitlab.com/dalibo/postgresql_anonymizer.git
```

_Step 1:_  Build the project like any other PostgreSQL extension:

```console
make extension
sudo make install
```

**NOTE**: If you have multiple versions of PostgreSQL on the server, you may
need to specify which version is your target by defining the `PG_CONFIG` and
`PGVER` env variable like this:

```console
make extension PG_CONFIG=/usr/lib/postgresql/14/bin/pg_config PGVER="14"
sudo make install PG_CONFIG=/usr/lib/postgresql/14/bin/pg_config PGVER="14"
```

_Step 2:_  Load the extension:

Please note that in order to load the extension you must connect to Postgresql
with a user having superuser privileges. Also, the extension
(as all Postgresql extensions) will be created only in the given database and
not globally.

```sql
ALTER DATABASE foo SET session_preload_libraries = 'anon';
```

(If you're already loading extensions that way, just add `anon` the current list)

_Step 3:_  Close your session and open a new one on the same PostgreSQL
database. Create the extension.

```sql
CREATE EXTENSION anon;
SELECT anon.init();
```

All new connections to the given database can now use the extension.





Install with Docker
------------------------------------------------------------------------------

If you can't (or don't want to) install the PostgreSQL Anonymizer extension
directly inside your instance, then you can use the docker image :

```console
docker pull registry.gitlab.com/dalibo/postgresql_anonymizer:stable
```

The image is available with 2 two tags:

* `latest` (default) contains the current developments
* `stable` is the based on the previous release

You can run the docker image like the regular [postgres docker image].

[postgres docker image]: https://hub.docker.com/_/postgres

For example:

Launch a postgres docker container

```console
docker run -d -e POSTGRES_PASSWORD=x -p 6543:5432 registry.gitlab.com/dalibo/postgresql_anonymizer
```

then connect:

```console
export PGPASSWORD=x
psql --host=localhost --port=6543 --user=postgres
```

The extension is already created and initialized, you can use it directly:

```sql
# SELECT anon.partial_email('daamien@gmail.com');
     partial_email
-----------------------
 da******@gm******.com
(1 row)
```


**Note:** The docker image is based on the latest PostgreSQL version and we do
not plan to provide a docker image for each version of PostgreSQL. However you
can build your own image based on the version you need like this:

```shell
DOCKER_PG_MAJOR_VERSION=16 make docker_image
```

Install as a "Black Box"
------------------------------------------------------------------------------

see [Anonymous Dumps]

[Anonymous Dumps]: anonymous_dumps.md


Install on MacOS
------------------------------------------------------------------------------

**WE DO NOT PROVIDE COMMUNITY SUPPORT FOR THIS EXTENSION ON MACOS SYSTEMS.**

However it should be possible to build the extension if you install the
[PGRX Mac OS system requirements] and then follow the regular
[install from source] procedure.

[PGRX Mac OS system requirements]: https://github.com/pgcentralfoundation/pgrx?tab=readme-ov-file#system-requirements

Install on Windows
------------------------------------------------------------------------------

PostgreSQL Anonymizer is built upon the [PGRX] framework and currently [PGRX]
does not support compiling PostgreSQL extensions for Windows.

This is means that there's no native build of PostgreSQL Anonymizer for Windows.

However is it possible to run PostgreSQL inside a WSL2 container, which is
basically an Ubuntu subsystem running on Windows.

You can then install PostgreSQL Anonymizer inside the WSL2 container like you
would on a regular Ubuntu server.

Please read the Windows documentation for more details:

* [Install WSL2]
* [Install PostgreSQL in WSL2]

[Install PostgreSQL in WSL2]: https://learn.microsoft.com/windows/wsl/tutorials/wsl-database#install-postgresql
[Install WSL2]: https://learn.microsoft.com/windows/wsl/install

Install in the cloud
------------------------------------------------------------------------------

This extension must be installed with superuser privileges, which is something
that most Database As A Service platforms (DBaaS), such as Amazon RDS or
Microsoft Azure SQL, do not allow. They must add the extension to their catalog
in order for you to use it.

At the time we are writing this (March 2024), the following platforms provide
PostgreSQL Anonymizer:

* [Crunchy Bridge]
* [Google Cloud SQL]
* [Microsoft Azure Database]
* [Neon]
* [Postgres.ai]
* [Tembo]

[Crunchy Bridge]: https://access.crunchydata.com/documentation/postgresql-anonymizer/latest/
[Google Cloud SQL]: https://cloud.google.com/sql/docs/postgres/extensions#postgresql_anonymizer
[Microsoft Azure Database]: https://learn.microsoft.com/fr-fr/azure/postgresql/flexible-server/concepts-extensions
[Neon]: https://neon.tech/blog/easily-anonymize-production-data-in-postgres
[Postgres.ai]: https://postgres.ai/docs/database-lab/masking
[Tembo]: https://tembo.io/blog/anon-dump

Please refer to their own documentation on how to activate the extension as they
might have a platform-specific install procedure.

If your favorite DBaaS provider is not present in the list above, there is not
much we can do about it... Although we have open discussions with some major
actors in this domain, we DO NOT have internal knowledge on whether or not they
will support it in the near future. If privacy and anonymity are a concern to
you, we encourage you to contact the customer service of these platforms and
ask them directly if they plan to add this extension to their catalog.



Addendum: Alternative way to load the extension
------------------------------------------------------------------------------

It is recommended to load the extension like this:

```sql
ALTER DATABASE foo SET session_preload_libraries='anon'
```

It has several benefits:

* First, it will be dumped by `pg_dump` with the`-C` option, so the database
  dump will be self efficient.

* Second, it is propagated to a standby instance by streaming replication.
  Which means you can use the anonymization functions on a read-only clone
  of the database (provided the extension is installed on the standby instance)


However, you can load the extension globally in the instance using the
`shared_preload_libraries` parameter :

```sql
ALTER SYSTEM SET shared_preload_libraries = 'anon'"
```

Then restart the PostgreSQL instance.



Addendum: Troubleshooting
------------------------------------------------------------------------------

If you are having difficulties, you may have missed a step during the
installation processes. Here's a quick checklist to help you:

### Check that the extension is present

First, let's see if the extension was correctly deployed:

```console
ls $(pg_config --sharedir)/extension/anon
ls $(pg_config --pkglibdir)/anon.so
```

If you get an error, the extension is probably not present on host server.
Go back to step 1.

### Check that the extension is loaded

Now connect to your database and look at the configuration with:

```sql
SHOW local_preload_libraries;
SHOW session_preload_libraries;
SHOW shared_preload_libraries;
```

If you don't see `anon` in any of these parameters, go back to step 2.

### Check that the extension is created

Again connect to your database and type:

```sql
SELECT * FROM pg_extension WHERE extname= 'anon';
```

If the result is empty, the extension is not declared in your database.
Go back to step 3.

### Check that the extension is initialized

Finally, look at the state of the extension:

```sql
SELECT anon.is_initialized();
```

If the result is not `t`, the extension data is not present.
Go back to step 3.


Uninstall
-------------------------------------------------------------------------------

_Step 1:_ Remove all rules

```sql
SELECT anon.remove_masks_for_all_columns();
SELECT anon.remove_masks_for_all_roles();
```

**THIS IS NOT MANDATORY !**  It is possible to keep the masking rules inside
the database schema even if the anon extension is removed !

_Step 2:_ Drop the extension

```sql
DROP EXTENSION anon;
```

The `anon` extension also installs [pgcrypto] as a dependency, if you
don't need it, you can remove it too:

```sql
DROP EXTENSION pgcrypto;
```

[pgcrypto]: https://www.postgresql.org/docs/current/pgcrypto.html

_Step 3:_ Unload the extension


```sql
ALTER DATABASE foo RESET session_preload_libraries;
```


_Step 4:_ Uninstall the extension

For Redhat / CentOS / Rocky:

```console
sudo yum remove postgresql_anonymizer_14
```

Replace 14 by the version of your postgresql instance.

Compatibility Guide
-------------------------------------------------------------------------------

PostgreSQL Anonymizer is designed to work on the most current setups.
As we are trying to find the right balance between innovation and backward
compatibility, we define a comprehensive list of platforms and software that
we officially support for each version.


| Version  | Released   | EOL       | Postgres |    OS                  |
|----------|------------|-----------|----------|------------------------|
| 2.0      | dec. 2024  | dec. 2025 | 13 to 17 | RHEL 8 & 9, Debian 11 & 12, Ubuntu 24.04 |
| 1.3      | mar. 2024  | dec. 2024 | 12 to 16 | RHEL 8 & 9 |
| 1.2      | jan. 2024  | mar. 2024 | 12 to 16 | RHEL 8 & 9 |
| 1.1      | sept. 2022 | jan. 2024 | 11 to 15 | RHEL 7 & 8 |

The extension may work on other distributions than the ones above, however
provide packages only for these versions and we do not guarantee free
community support for other OS.

If you need support on other platforms, we may offer commercial support for it.
Please contact our commercial team at <contact@dalibo.com> for more details.
