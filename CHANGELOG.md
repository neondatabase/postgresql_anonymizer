CHANGELOG
===============================================================================


2019FIXME : 0.3.1 - Shuffle and Variance
-------------------------------------------------------------------------------

* shuffle an entire column with the new function : 
	```sql
	SELECT anon.shuffle_column('employees','salary');
	```

* Add +/-33% of noise to a column with:
	```sql
  SELECT anon.numeric_noise_on_column('employees','salary',0.33);
	```

* Add +/-10 years of noise to a date with :
  ```sql
  SELECT anon.datetime_noise_on_column('employees','birth_day','10 years');
  ```

* Renamed faking functions for clarity

* FIX #43 : Using unlogged tables was a bad idea

* FIX #51 : tests & doc about explicit casting
 


20181029 : 0.2.1 - Dynamic masking and partial functions
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
