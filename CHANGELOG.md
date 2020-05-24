CHANGELOG
===============================================================================

2020FIXME : 0.7.0 - WORK IN PROGRESS
-------------------------------------------------------------------------------

__Dependencies:__
- pgcrypto
- tms_system_rows

* [install] Add a notice to users when they try to load the extension twice
* [CI] Improve the masking test
* Support for PostgreSQL 13
* [noise] add on-the-fly noise functions (Gunnar Nick Bluth)
* [dump] add a hint if a particular table dump fails (Gunnar Nick Bluth)
* FIX #128: add version function and use it in pg_dump_anon (Yann ROBIN)
* [doc] Security: explain noise reduction attacks
* [doc] How To mask a JSONB column (Fabien BARBIER)
* [doc] improve load doc
* [CI] Test install on Ubuntu Bionic
* [doc] DBaaS providers support for EVENT TRIGGERS and dynamic masking (Martin Kubrak)
* [install] Remove dependency to the ddlx extension
* FIX #123 : bug in the standalone install script (Florian Desbois)


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
