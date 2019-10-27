CHANGELOG
===============================================================================

2019FIXME : 0.5.0 - Generalization and K-Anonymity
-------------------------------------------------------------------------------

* FIX #93 : better install documentation


20191018 : 0.4.1 - bugfix release
-------------------------------------------------------------------------------

__Dependencies:__
  - tms_system_rows
  - ddlx

* FIX #87 : anon.config loaded twice with pg_restore
* [doc] : install with yum

20191014 : 0.4 - Declare Masking Rules With Security Labels
-------------------------------------------------------------------------------

__Dependencies:__
  - tms_system_rows
  - ddlx

* Use Security Labels instead of COMMENTs. COMMENTs are still supported

* Automatic Type Casting

* Improve documentation



20190826 : 0.3 - In-place Anonymization and Anonymous dumps
-------------------------------------------------------------------------------

__Dependencies:__
  - tms_system_rows
  - ddlx

* In-place Anonymization : Permanently remove sensitive data
  with `anonymize_database()`, `anonymize_table()` or
  `anonymize_column()`.

* Anonymous dumps : Export the entire anonymized database with
  the new `dump()` function. For instance:

  ```console
  $ psql -q -t -A -c 'SELECT anon.dump()' the_database
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

## Declare masking rules within the DDL :

* Declare a masked column with :
  ```sql
  COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';
  ```

* Declare a masked role with :
  ```sql
  COMMENT ON ROLE untrusted_user IS 'MASKED';
  ```

## New functions for partial scrambling

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
