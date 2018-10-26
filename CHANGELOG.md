CHANGELOG
===============================================================================


20181026 : 0.2.1 - Dynamic masking and partial functions
-------------------------------------------------------------------------------

* Declare a masked column with :
  ```sql
  COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';
  ```

* Declare a masked role with :
  ```sql
  COMMENT ON ROLE skynet IS 'MASKED';
  ```

* `email()` will partially hide an email

* `partial()` will partially hide any TEXT value


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
