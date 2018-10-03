Anonymizing and Masking Data with PostgreSQL
===============================================================================

`postgresql_anonymizer` is a set of SQL functions that hide or replace
[personally identifiable information] (PII) or commercially sensitive data
from a PostgreSQL database.

The projet is aiming toward a **declarative approach** of anonymization. This
means we're trying to extend PostgreSQL Data Definition Language (DDL) in
order to specify the anonymization strategy inside the table definition itself.
Read the [Concepts] section for more details.

[personally indentifiable information](https://en.wikipedia.org/wiki/Personally_identifiable_information)


Warning
------------------------------------------------------------------------------

*This is projet is at an early stage of development and should used carefully.* I

I need your feedback and ideas ! Let me know what you think of this tool,how it
fits your needs and what features are missing.

You can either [open an issue] or send a message at <daamien@gmail.com>.

[open an issue](https://gitlab.com/daamien/postgresql_anonymizer/issues)

Example
------------------------------------------------------------------------------

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;

=# SELECT anon.load();

=# SELECT * FROM customer;
 id  |   full_name      |   birth    |    employer   | zipcode | fk_shop
-----+------------------+------------+---------------+---------+---------
 911 | Chuck Norris     | 1940-03-10 | Texas Rangers | 75001   | 12
 112 | David Hasselhoff | 1952-07-17 | Baywatch      | 90001   | 423

=# UPDATE customer
-# SET
-#   full_name=anon.random_first_name() || ' ' || anon.random_last_name(),
-#   birth=anon.random_date_between('01/01/1920'::DATE,now()),
-#   employer=anon.random_company(),
-#   zipcode=anon.random_zip()
-# ;

=# SELECT * FROM customer;
 id  |     full_name     |   birth    |     employer     | zipcode | fk_shop
-----+-------------------+------------+------------------+---------+---------
 911 | michel Duffus     | 1970-03-24 | Body Expressions | 63824   | 12
 112 | andromache Tulip  | 1921-03-24 | Dot Darcy        | 73231   | 423
```

Declarative Data Masking
--------------------------------------------------------------------------------

STEP 0 : Imagine a `people` table

```sql
=# SELECT * FROM people;
  id  |      name      |   phone
------+----------------+------------
 T800 | Schwarzenegger | 0609110911
(1 row)
```

STEP 1 : Activate the masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.mask_init();
```

STEP 2 : Declare a masked user

```sql
=# CREATE ROLE skynet;
=# COMMENT ON ROLE skynet IS 'MASKED';
```

STEP 3 : Declare the masking rules

```sql
=# COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';

=# COMMENT ON COLUMN people.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

STEP 4 : Connect with the masked user

```sql
=# \! psql test -U skynet -c 'SELECT * FROM people;'
  id  |   name   |   phone
------+----------+------------
 T800 | Nunziata | 06******11
(1 row)
```

Requirements
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.
It should also work on PostgreSQL 9.5 with a bit of hacking.

It requires an extension named `tsm_system_rows`, which is delivered by the
`postgresql-contrib` package of the main linux distributions.

Install
-------------------------------------------------------------------------------

### With [PGXN](https://pgxn.org/) :

```console
sudo apt install pgxnclient (or pip install pgxn)
sudo pgxn install postgresql_anonymizer
```

### From source :

```console
make
sudo make install
```


How To Use
------------------------------------------------------------------------------

Load the extension in your database like this:

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();
```

The `load()` function will charge a default dataset of random data ( lists
names, cities, etc. ). If you want to use your own dataset, you can load
custom CSV files with `load('/path/to/custom_cvs_files/')`

**You now have access to the following functions :**

### Generic data

* anon.random_date() returns a date
* anon.random_date_between(d1,d2) returns a date between `d1` and `d2`
* anon.random_int_between(i1,i2) returns an integer between `i1` and `i2`
* anon.random_string(n) returns a TEXT value containing `n` letters

### Personal data

* anon.random_first_name() returns a generic first name
* anon.random_last_name() returns a generic last name
* anon.random_email() returns a valid email address
* anon.random_zip() returns a 5-digit code
* anon.random_city() returns an existing city
* anon.random_city_in_country(c) returns a city in country `c`
* anon.random_region() returns an existing region
* anon.random_region_in_country(c) returns a region in country `c`
* anon.random_country() returns a country
* anon.random_phone(p) return a 8-digit phone with `p` as a prefix

### Company data

* anon.random_company() returns a generic company name
* anon.random_iban() returns a valid IBAN
* anon.random_siret() returns a valid SIRET
* anon.random_siren() returns a valid SIREN


Upgrade
------------------------------------------------------------------------------

Currently there's no way to upgrade easily from a version to another.
The operation `ALTER EXTENSION ... UPDATE ...` is not supported.

You need to drop and recreate the extension after every upgrade.


Concepts
------------------------------------------------------------------------------

Two main strategies are used:

* **Dynamic Masking** offers an altered view of the real data without
  modifying it. Some users may only read the masked data, others may access
  the authentic version.

* **Permanent Destruction** is the definitive action of substituting the
  sensitive information with uncorrelated data. Once processed, the authentic
  data cannot be retrieved.

The data can be altered with several techniques:

1. **Deletion** or **Nullification** simply removes data.

2. **Static Subtitution** consistently replaces the data with a generic
   values. For instance: replacing all values of TEXT column with the value
   "CONFIDENTIAL".

3. **Variance** is the action of "shifting" dates and numeric values. For
   example, by applying a +/- 10% variance to a salary column, the dataset will
   remain meaningful.

4. **Encryption** uses an encryption algorithm and requires a private key. If
   the key is stolen, authentic data can be revealed.

5. **Shuffling** mixes values within the same columns. This method is open to
   being reversed if the shuffling algorithm can be deciphered.

6. **Randomization** replace sensitive data with **random-but-plausible**
   values. The goal is to avoid any identification from the data record while
   remaining suitable for testing, data analysis and data processing.

7. **Partial scrambling** is similar to static substitution but leaves out some
   part of the data. For instance : a credit card number can be replaced by
   '40XX XXXX XXXX XX96'

8. **Custom rules** are designed to alter data following specific needs. For
   instance, randomizing simultanously a zipcode and a city name while keeping
   them coherent.

For now, this extension is especially focusing on  **randomization** and
**Partial Scrambling** and **Custom Rules** but it should be easy to implement
other methods as well.




Performance
------------------------------------------------------------------------------

So far, we've done very few performance tests. Depending on the size of your
data set and number of columns your need to anonymize, you might end up with a
very slow process.

Here's some ideas :

### Sampling

If your need to anonymize data for testing purpose, chances are that a smaller
subset of your database will be enough. In that case, you can easily speed up
the anonymization by downsizing the volume of data. There are mulitple way to
extract a sample of database :

* [TABLESAMPLE](https://www.postgresql.org/docs/current/static/sql-select.html)
* [pg_sample](https://github.com/mla/pg_sample)



### Dynamic Masking

If you need to limit sensitive data exposure to non-privileged users, you can
build _Dynamic Masking Views_ that will automatically replace personal data
with anonymized values.

For instance:

```SQL
CREATE VIEW masked_customer AS
SELECT
    id,
    anon.random_last_name() AS name,
    anon.random_date_between('01/01/1920'::DATE,now()) AS birth,
    fk_last_order,
    store_id
FROM customer;
```

In certain use cases, [Materialized Views] can be usefull here.


[Materialized Views](https://www.postgresql.org/docs/current/static/sql-creatematerializedview.html)




Links
--------------------------------------------------------------------------------

* Dynamic Data Masking With MS SQL Server
  <https://docs.microsoft.com/fr-fr/sql/relational-databases/security/dynamic-data-masking>

* Citus : Using search_path and views to hide columns for reporting with Postgres
  <https://www.citusdata.com/blog/2018/07/03/masking-columns-in-postgresql/>

* MariaDB : Masking with maxscale
  <https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-21-masking/>

* pgsync
  <https://github.com/ankane/pgsync>
