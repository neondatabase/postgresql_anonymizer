
PostgreSQL Anonymizer 0.3 : In-Place Masking and Anonymous Dumps
================================================================================

Paris, FIXME

`postgresql_anonymizer` is an extension that hides or replaces personally 
identifiable information (PII) or commercially sensitive data from a PostgreSQL 
database.

Firts of all, you declare a list of [masking rules] directly inside the database 
model with SQL comments like this :

```
COMMENT ON COLUMN users.name IS 'MASKED WITH FUNCTION md5(name)';
```

Once the masking rules are declared, anomization can be acheived in 3 
different ways:

* [Anonymous Dumps]: Simply export the masked data into an SQL file
* [In-Place Anonymization]: Remove the sensible data according to the rules
* [Dynamic Masking]: Hide sensible data, only for the masked users

In addition, various masking functions are available : randomization, faking,
partial scrambling, shuffling, noise, etc... You can also user your own custom 
function !

For more detail, please take a look at the documention:
https://postgresql-anonymizer.readthedocs.io/

[masking rules]: https://postgresql-anonymizer.readthedocs.io/en/latest/declare_masking_rules/
[Anonymous Dumps]: https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/
[In-Place Anonymization]: https://postgresql-anonymizer.readthedocs.io/en/latest/in_place_anonymization/
[Dynamic Masking]: https://postgresql-anonymizer.readthedocs.io/en/latest/dynamic_masking/


How to Install
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.

It requires extension named [tsm_system_rows] (available in the `contrib` 
package) and an extension called [ddlx] (available via PGXN) :

```
$ pgxn install ddlx
$ pgxn install postgresql_anonymizer
```

**WARNING:** The project is at an early stage of development and should be used 
carefully.



How to contribute
--------------------------------------------------------------------------------


FIXME : I'd like to thanks all my wonderful colleagues at [Dalibo] for their support 
and especially Thibaut Madelaine for the initial ideas.

This is an open project, contributions are welcome. I need your feedback and 
ideas ! Let me know what you think of this tool, how it fits your needs and 
what features are missing.

If you want to help, you can find a list of `Junior Jobs` here:

https://gitlab.com/dalibo/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs


[Dalibo Labs]: https://labs.dalibo.com




------------------------------------------------


Introducing PostgreSQL Anonymizer 0.2.1 !
================================================================================

Paris, october 29, 2018

`postgresql_anonymizer` is an extension to mask or replace personally identifiable 
information (PII) or commercially sensitive data from a PostgreSQL database.

The projet is aiming toward a **declarative approach** of anonymization. This
means we're trying to extend PostgreSQL's Data Definition Language (DDL) in
order to specify the anonymization strategy inside the table definition itself.

The extension can be used to put dynamic masks on certain users or permanently 
modify sensitive data. Various masking techniques are available : randomization, 
partial scrambling, custom rules, etc.

This tool is distributed under the PostgreSQL licence and the code is here:

https://gitlab.com/daamien/postgresql_anonymizer

Example
--------------------------------------------------------------------------------

Imagine a `people` table

```sql
=# SELECT * FROM people;
  id  |      name      |   phone
------+----------------+------------
 T800 | Schwarzenegger | 0609110911
```

### STEP 1 : Activate the masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.mask_init();
```

### STEP 2 : Declare a masked user

```sql
=# CREATE ROLE skynet;
=# COMMENT ON ROLE skynet IS 'MASKED';
```

### STEP 3 : Declare the masking rules

```sql
=# COMMENT ON COLUMN people.name IS 'MASKED WITH FUNCTION anon.random_last_name()';

=# COMMENT ON COLUMN people.phone IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

### STEP 4 : Connect with the masked user

```sql
=# \! psql test -U skynet -c 'SELECT * FROM people;'
  id  |   name   |   phone
------+----------+------------
 T800 | Nunziata | 06******11
```

How to Install
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.
It should also work on PostgreSQL 9.5 with a bit of hacking.

It requires an extension named `tsm_system_rows`, which is delivered by the
postgresql-contrib package of the main linux distributions

You can install it with `pgxn` or build from source it like any other 
extenstion.

**WARNING:** The project is at an early stage of development and should be used carefully.


How to contribute
--------------------------------------------------------------------------------

I'd like to thanks all my wonderful colleagues at [Dalibo] for their support 
and especially Thibaut Madelaine for the initial ideas.

This is an open project, contributions are welcome. I need your feedback and 
ideas ! Let me know what you think of this tool, how it fits your needs and 
what features are missing.

If you want to help, you can find a list of `Junior Jobs` here:

<https://gitlab.com/daamien/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs>

[Dalibo]: https://dalibo.com