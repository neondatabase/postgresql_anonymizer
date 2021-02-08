CHANGELOG
===============================================================================


20200201 : 0.8.0 - WORK IN PROGRESS
-------------------------------------------------------------------------------

<!-- https://gitlab.com/dalibo/postgresql_anonymizer/-/milestones/11 -->

__Dependencies:__

- tms_system_rows
- pg_crypto

__Changes:__

* [doc] FIX #168: how to alter a masked column (Rodrigo Otsuka)
* [doc] FIX #174: How to anonymize 2 columns simultaneously (Nicolas Peltier)
* [rules] FIX #181: handle all chars in MASKED WITH VALUES (Matthieu Larcher)
* [in-place] Refactor anonymize_database to improve perfs  (Sébastien Helbert)
* [core] Add support of partitioned tables (Dmitry Fomin)
* [core] Add support of foreign tables (Paul Bonaud)
* [core] Add schemaname in `pg_masking_rules`
* [doc] Explain the permission model
* [docker] simplify the build process for different PG major versions
* [core] FIX #198: bug in the `shuffle` mecanism
* [doc] Documentation Improvements (Rushal Verma)
* [core] Improve the random generator, deprecated use of `tms_system_rows`



20200928 : 0.7.1 - bugfix release
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- pg_crypto

__Changes:__

* [pgxn] fixup META.json

20200925 : 0.7.0 - Generic Hashing and Advanced Faking
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- pg_crypto

__Changes:__

* [install] Add a notice to users when they try to load the extension twice
* [CI] Improve the masking test
* [install] Support for PostgreSQL 13
* [noise] add on-the-fly noise functions (Gunnar Nick Bluth)
* [dump] add a hint if a particular table dump fails (Gunnar Nick Bluth)
* [install] FIX #128: add version function (Yann Robin)
* [doc] Security: explain noise reduction attacks
* [doc] How To mask a JSONB column (Fabien Barbier)
* [doc] improve load doc
* [CI] Test install on Ubuntu Bionic
* [doc] DBaaS providers support for EVENT TRIGGERS and dynamic masking (Martin Kubrak)
* [install] Remove dependency to the ddlx extension
* [install] FIX #123: bug in the standalone install script (Florian Desbois)
* [doc] lint markdown
* [hashing] Introducing generic hashing function (Gunnar Nick Bluth)
* [hashing] Storing the hashing salt in a secret table
* [hashing] Add dependency to the pg_crypto extension
* [init] Rename anon.load() to anon.init() for clarity
* [random] new masking function: `anon.random_in(ARRAY['yes','no','maybe'])`
* [in-place] defer all deferrable constraints
* [doc] how to dump roles when using the black box method
* [dump] FIX #146: export sequences data  (Joe Auty)
* [doc] `anon.shuffle()` is not a masking function
* [dump] FIX #129: `--file` option not working (Yann Robin)
* [dump] use arrays for argument lists
* [dump] use shellcheck
* [docker] automatic publication of the `latest` tag
* [masking] FIX #141 `anon.stop_dynamic_masking()` does not remove the mask schema
* [init] fix `anon.reset()`
* [init] FIX #103: Create extension encoding issue (Dattatray Phadtare)
* [init] improve error handling
* [init] add the oid into the CSV tables
* [init] Initcap on table `first_name`
* [doc] Add a troubleshooting guide
* [doc] Typo (Peter Neave)
* [doc] Choose between stable and latest
* [blackbox] FIX #156 stdout permissions (Ilya Gorbunov)
* [init] better error handling
* [init] rename anon.load() to anon.init()
* [doc] how to use the PostgreSQL Faker extension
* [dump] Ignore .psqlrc (Nikolay Samokhvalov)



20200305 : 0.6.0 - Pseudonymization and Improved anonymous dumps
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- ddlx

__Changes:__

* [doc] Typos, grammar (Nikolay Samokhvalov)
* [doc] make help
* [security] declare explicitly all function as `SECURITY INVOKER`
* [doc] typos (Sebastien Delobel)
* [docker] improve the "black box" method (Sam Buckingham)
* [dump] Fix #112 : invalid command \."
* [install] use session_preload_libs instead of shared_preload_libs (Olleg Samoylov)
* [anonymize] FIX #114 : bug in anonymize_table() (Joe Auty)
* [bug] Fix syntax error when schema in not in search_path (Olleg Samoylov)
* [doc] Use ISO 8601 for dates (Olleg Samoylov)
* [dump] anon.dump() is not deprecated
* [dump] introducing `pg_dump_anon` command line tool
* [pseudo] introducing pseudonymization functions
* [doc] clean up, typos and reorg
* [detection] introducing the identifiers detection function
* [dump] Allow only partial database dump - Or ignoring specific tables



20191106 : 0.5.0 - Generalization and k-anonymity
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- ddlx

__Changes:__

* Introduce the Generalization method with 6 functions that transforms dates
  and numeric values into ranges of value.

* Introduce a k-anonymity assessment function.

* [faking] Add `anon.lorem_ipsum()` to generate classic lorem ipsum texts
* [destruction] New syntax `MASKED WITH VALUE ...`
* [doc] Install on Ubuntu 18.04 (many thanks to Jan Birk )
* [doc] Install with docker
* FIX #93 : Better install documentation
* FIX #95 : Building on FreeBSD/MacOS (many thanks to Travis Miller)



20191018 : 0.4.1 - bugfix release
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- ddlx

__Changes:__

* FIX #87 : anon.config loaded twice with pg_restore (Olleg Samoylov)
* [doc] : install with yum

20191014 : 0.4 - Declare Masking Rules With Security Labels
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- ddlx

__Changes:__

* Use Security Labels instead of COMMENTs. COMMENTs are still supported

* Automatic Type Casting

* Improve documentation



20190826 : 0.3 - In-place Anonymization and Anonymous dumps
-------------------------------------------------------------------------------

__Dependencies:__

- tms_system_rows
- ddlx

__Changes:__

* In-place Anonymization : Permanently remove sensitive data
  with `anonymize_database()`, `anonymize_table()` or
  `anonymize_column()`.

* Anonymous dumps : Export the entire anonymized database with
  the new `dump()` function. For instance:

  ```console
  psql -q -t -A -c 'SELECT anon.dump()' the_database
  ```

* Dynamic Masking : new functions `start_dynamic_masking()` and
  `stop_dynamic_masking()`

* shuffle an entire column with the new function :

  ```sql
  SELECT anon.shuffle_column('employees','salary', 'id');
  ```

* Add +/-33% of noise to a column with:

  ```sql
  SELECT anon.numeric_noise_on_column('employee','salary',0.33);
  ```

* Add +/-10 years of noise to a date with :

  ```sql
  SELECT anon.datetime_noise_on_column('employee','birthday','10 years');
  ```

* Renamed faking functions for clarity

* FIX #43 : Using unlogged tables was a bad idea

* FIX #51 : tests & doc about explicit casting

* Add `autoload` parameter to `mask_init` function.
  Default to TRUE for backward compatibility

* Add `anon.no_extension.sql` for people in the cloud

* [masking] Improve security tests


20181029 : 0.2 - Dynamic masking and partial functions
-------------------------------------------------------------------------------

### Declare masking rules within the DDL

* Declare a masked column with:

  ```sql
  COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';
  ```

* Declare a masked role with :

  ```sql
  COMMENT ON ROLE untrusted_user IS 'MASKED';
  ```

### New functions for partial scrambling

* `partial()` will partially hide any TEXT value
* `partial_email()` will partially hide an email address


Checkout `demo/partial.sql` and `demo/masking.sql` for more details


20180918 : 0.1.1 - Load a custom dataset
-------------------------------------------------------------------------------

* [doc] How To Contribute
* Add tsm_system_rows in `requires` clause
* Allow loading à custom dataset
* use UNLOGGED tables to speed extension loading


20180831 : 0.0.3 - PGXN Fixup
-------------------------------------------------------------------------------

* FIX #12 : bad package version

20180827 : 0.0.2 - Minor bug
-------------------------------------------------------------------------------

* FIX #11 : install error

20180801 : 0.0.1 - Proof of Concept
-------------------------------------------------------------------------------

* `random_date()` and `random_date_between()``
* `random_string()`
* `random_zip()`
* `random_company()`, `random_siret()`, `random_iban()`
* `random_first_name()`, `random_last_name()`
* Docker file for CI
* tests
* PGXN package
