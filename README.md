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
=# CREATE EXTENSION IF NOT EXISTS tsm_system_rows;
=# CREATE EXTENSION IF NOT EXISTS anon;

=# SELECT * FROM customer;
    full_name     |   birth    |    employer   | zipcode
------------------+------------+---------------+---------
 Chuck Norris     | 1940-03-10 | Texas Rangers | 75001
 David Hasselhoff | 1952-07-17 | Baywatch      | 90001

=# UPDATE customer
-# SET
-#   full_name=anon.random_first_name() || ' ' || anon.random_last_name(),
-#   birth=anon.random_date_between('01/01/1920'::DATE,now()),
-#   employer=anon.random_company(),
-#   zipcode=anon.random_zip()
-# ;

=# SELECT * FROM customer;
     full_name     |   birth    |     employer     | zipcode
-------------------+------------+------------------+---------
 michel Duffus     | 1970-03-24 | Body Expressions | 63824
 andromache Tulip  | 1921-03-24 | Dot Darcy        | 73231
```


Requirements
------------------------------------------------------------------------------

This extension will work with PostgreSQL 9.5 and later versions. 
It requires an extension named `tsm_system_rows` which is delivered by the 
package `postgresql-contrib` of the main linux distributions.

Install
-------------------------------------------------------------------------------

### With [PGXN](https://pgxn.org/) :

```console
pip install pgxnclient
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
CREATE EXTENSION IF NOT EXISTS tsm_system_rows;
CREATE EXTENSION IF NOT EXISTS anon;
```

You now have access to the following function :


* anon.random_date() : return a date 
* anon.random_date_between(d1,d2) : will a date between `d1` and `d2`
* anon.random_int_between(i1,i2) : returns an integer between `i1` and `i2`
* anon.random_string(n) : return a TEXT value containing `n` letters
* anon.random_zip() : returns a 5-digit code
* anon.random_company() : returns a generic company name
* anon.random_first_name() : returns a generic first name
* anon.random_last_name() : returns a generic last name

### Anonymize company data

random_iban()                                                                                                               
random_siren()        

Performance
------------------------------------------------------------------------------



Feedback
------------------------------------------------------------------------------
