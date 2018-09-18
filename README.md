Data Anonymizer Extension for PostgreSQL
===============================================================================

`postgresql_anonymizer` is a set of SQL functions that remove personally
identifiable values from a PostgreSQL table and replace them with
**random-but-plausible** values. The goal is to avoid any identification
from the data record while remaining suitable for testing, data analysis and
data processing.

*This is projet is at an early stage of development and should used carefully.*


Example
------------------------------------------------------------------------------

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;

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


Requirements
------------------------------------------------------------------------------

This extension will work with PostgreSQL 9.5 and later versions. 

It requires an extension named `tsm_system_rows`, which is delivered by the 
`postgresql-contrib` package of the main linux distributions.

Install
-------------------------------------------------------------------------------

### With [PGXN](https://pgxn.org/) :

```console
apt install pgxnclient (or pip install pgxn)
pgxn install postgresql_anonymizer
```



### From source :

```console
make
make install
```


How To Use
------------------------------------------------------------------------------

Load the extension in your database like this:

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
```

You now have access to the following functions :

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
* anon.random_iban() : returns a valid IBAN
* anon.random_siret() : returns a valid SIRET
* anon.random_siren() : returns a valid SIREN
         


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


Feedback
------------------------------------------------------------------------------

