
PostgreSQL Anonymizer 0.5 : Generalization and k-anonymity
================================================================================

Eymoutiers, France, November FIXME, 2019

`Postgresql Anonymizer` is an extension that hides or replaces personally 
identifiable information (PII) or commercially sensitive data from a PostgreSQL 
database.

The extension supports 3 different anonymization strategies : [Dynamic Masking], 
[In-Place Anonymization] and [Anonymous Dumps]. It also offers a large choice of 
[Masking Functions]: Substitution, Randomization, Faking, Partial Scrambling, 
Shuffling, Noise Addition and Generalization.

[Masking Functions]: https://postgresql-anonymizer.readthedocs.io/en/latest/masking_functions/
[Anonymous Dumps]: https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/
[In-Place Anonymization]: https://postgresql-anonymizer.readthedocs.io/en/latest/in_place_anonymization/
[Dynamic Masking]: https://postgresql-anonymizer.readthedocs.io/en/latest/dynamic_masking/

Generalization
--------------------------------------------------------------------------------

The idea of generalization is to replace data with a broader, less accurate 
value. For instance, instead of saying "Bob is 28 years old", you can say 
"Bob is between 20 and 30 years old". This is interesting for analytics because
the data remains true while avoiding the risk of re-identification.

PostgreSQL can handle generalization very easily with the [RANGE] data types,
a very powefull way to store and manipulate a set of values contained between
a lower and an upper bound.

[RANGE]: https://www.postgresql.org/docs/current/rangetypes.html

Here's a basic table containing medical data:

```sql
SELECT * FROM patient;
     ssn     | firstname | zipcode |   birth    |    disease    
-------------+-----------+---------+------------+---------------
 253-51-6170 | Alice     |   47012 | 1989-12-29 | Heart Disease
 091-20-0543 | Bob       |   42678 | 1979-03-22 | Allergy
 565-94-1926 | Caroline  |   42678 | 1971-07-22 | Heart Disease
 510-56-7882 | Eleanor   |   47909 | 1989-12-15 | Acne
```

We want the anonymized data to remain **true** because it will be
used for statistics. We can build a view upon this table to remove 
useless columns and generalize the indirect identifiers (zipcode and 
birthday):

```sql
CREATE MATERIALIZED VIEW generalized_patient AS
SELECT
  'REDACTED'::TEXT AS firstname,
  anon.generalize_int4range(zipcode,1000) AS zipcode,
  anon.generalize_daterange(birth,'decade') AS birth,
  disease
FROM patient;
```

This will give us a less accurate view of the data:

```sql
SELECT * FROM generalized_patient;
 firstname |    zipcode    |          birth          |    disease    
-----------+---------------+-------------------------+---------------
 REDACTED  | [47000,48000) | [1980-01-01,1990-01-01) | Heart Disease
 REDACTED  | [42000,43000) | [1970-01-01,1980-01-01) | Allergy
 REDACTED  | [42000,43000) | [1970-01-01,1980-01-01) | Heart Disease
 REDACTED  | [47000,48000) | [1980-01-01,1990-01-01) | Acne
```


k-anonymity
--------------------------------------------------------------------------------

k-anonymity is an industry-standard term used to describe a property of an 
anonymized dataset. The k-anonymity principle states that within a 
given dataset, any anonymized individual cannot be distinguished from at 
least `k-1` other individuals. In other words, k-anonymity might be described 
as a "hiding in the crowd" guarantee. A low value of `k` indicates there's a risk
of re-identification using linkage with other data sources.

You can evaluate the k-anonymity factor of a table in 2 steps :

1. First defined the columns that are [indirect idenfiers] ( also known
   as "quasi identifers") like this:

```sql
SECURITY LABEL FOR anon ON COLUMN generalized_patient.zipcode 
IS 'INDIRECT IDENTIFIER';

SECURITY LABEL FOR anon ON COLUMN generalized_patient.birth 
IS 'INDIRECT IDENTIFIER';
```

2. Once the indirect identifiers are declared :

```sql
SELECT anon.k_anonymity('generalized_patient')
```

In the example above, the k-anonymity factor of the `generalized_patient` 
materialized view is `2`.

Lorem Ipsum
--------------------------------------------------------------------------------

For TEXT and VARCHAR columns, you can now use the classic [Lorem Ipsum] 
generator:

* `anon.lorem_ipsum()` returns 5 paragraphs
* `anon.lorem_ipsum(2)` returns 2 paragraphs
* `anon.lorem_ipsum( paragraphs := 4 )` returns 4 paragraphs
* `anon.lorem_ipsum( words := 20 )` returns 20 words
* `anon.lorem_ipsum( characters := 7 )` returns 7 characters

[Lorem Ipsum]: https://lipsum.com

How to Install
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.

On Red Hat / CentOS systems, you can install it from the 
[official PostgreSQL RPM repository]:

```
$ yum install postgresql_anonymizer12
```

Then add 'anon' in the `shared_preload_libraries` parameter of your 
`postgresql.conf` file. And restart your instance. 

For other system, check out the [install] documentation :

https://postgresql-anonymizer.readthedocs.io/en/latest/INSTALL/

> **WARNING:** The project is at an early stage of development and should be 
> used carefully.

[official PostgreSQL RPM repository]: https://yum.postgresql.org/
[install]: https://postgresql-anonymizer.readthedocs.io/en/latest/INSTALL/

Thanks 
--------------------------------------------------------------------------------

This release includes code and ideas from Travis Miller, Jan Birk and Olleg 
Samoylov. Many thanks to them !


How to contribute
--------------------------------------------------------------------------------

PostgreSQL Anonymizer is part of the [Dalibo Labs] initiative. It is mainly 
developed by [Damien Clochard].

This is an open project, contributions are welcome. We need your feedback and 
ideas ! Let us know what you think of this tool, how it fits your needs and 
what features are missing.

If you want to help, you can find a list of `Junior Jobs` here:

https://gitlab.com/dalibo/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs


[Dalibo Labs]: https://labs.dalibo.com
[Damien Clochard]: https://www.dalibo.com/en/equipe#daamien



--------------------------------------------------------------------------------


PostgreSQL Anonymizer 0.4 : Declare Masking Rules With Security Labels
================================================================================

Eymoutiers, October 14, 2019

`Postgresql Anonymizer` is an extension that hides or replaces personally 
identifiable information (PII) or commercially sensitive data from a PostgreSQL 
database.

This new version introduces a major change of syntax. In the previous versions, 
the data masking rules were declared with column comments. They are now defined 
by using [security labels]:

[security labels]: https://www.postgresql.org/docs/current/sql-security-label.html

```sql
SECURITY LABEL FOR anon 
ON COLUMN customer.lastname 
IS 'MASKED WITH FUNCTION anon.fake_last_name()'
```

The previous syntax is still supported and backward compatibility is maintained.


How to Install
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.

It requires extension named [tsm_system_rows] (available in the `contrib` 
package) and an extension called [ddlx] (available via [PGXN]) :

```
$ pgxn install ddlx
$ pgxn install postgresql_anonymizer
```

Then add 'anon' in the `shared_preload_libraries` parameter of your 
`postgresql.conf` file. And restart your instance. 

> **WARNING:** The project is at an early stage of development and should be used 
> carefully.

[tsm_system_rows]: https://www.postgresql.org/docs/current/tsm-system-rows.html
[ddlx]: https://github.com/lacanoid/pgddl
[PGXN]: https://pgxn.org/


How to contribute
--------------------------------------------------------------------------------

PostgreSQL Anonymizer is part of the [Dalibo Labs] initiative. It is mainly 
developed by [Damien Clochard].

This is an open project, contributions are welcome. We need your feedback and 
ideas ! Let us know what you think of this tool, how it fits your needs and 
what features are missing.

If you want to help, you can find a list of `Junior Jobs` here:

https://gitlab.com/dalibo/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs


[Dalibo Labs]: https://labs.dalibo.com
[Damien Clochard]: https://www.dalibo.com/en/equipe#daamien



------------------------------------------------



PostgreSQL Anonymizer 0.3 : In-Place Masking and Anonymous Dumps
================================================================================

Paris, August 26, 2019

`postgresql_anonymizer` is an extension that hides or replaces personally 
identifiable information (PII) or commercially sensitive data from a PostgreSQL 
database.

Firts of all, you declare a list of [Masking Rules] directly inside the database 
model with SQL comments like this :

```
COMMENT ON COLUMN users.name IS 'MASKED WITH FUNCTION md5(name)';
```

Once the masking rules are declared, anonymization can be acheived in 3 
different ways:

* [Anonymous Dumps]: Simply export the masked data into an SQL file
* [In-Place Anonymization]: Remove the sensible data according to the rules
* [Dynamic Masking]: Hide sensible data, only for the masked users

In addition, various [Masking Functions] are available : randomization, faking,
partial scrambling, shuffling, noise, etc... You can also user your own custom 
function !

For more detail, please take a look at the documention:
https://postgresql-anonymizer.readthedocs.io/

[Masking Rules]: https://postgresql-anonymizer.readthedocs.io/en/latest/declare_masking_rules/
[Masking Functions]: https://postgresql-anonymizer.readthedocs.io/en/latest/masking_functions/
[Anonymous Dumps]: https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/
[In-Place Anonymization]: https://postgresql-anonymizer.readthedocs.io/en/latest/in_place_anonymization/
[Dynamic Masking]: https://postgresql-anonymizer.readthedocs.io/en/latest/dynamic_masking/


How to Install
--------------------------------------------------------------------------------

This extension is officially supported on PostgreSQL 9.6 and later.

It requires extension named [tsm_system_rows] (available in the `contrib` 
package) and an extension called [ddlx] (available via [PGXN]) :

```
$ pgxn install ddlx
$ pgxn install postgresql_anonymizer
```

> **WARNING:** The project is at an early stage of development and should be used 
> carefully.

[tsm_system_rows]: https://www.postgresql.org/docs/current/tsm-system-rows.html
[ddlx]: https://github.com/lacanoid/pgddl
[PGXN]: https://pgxn.org/


How to contribute
--------------------------------------------------------------------------------

PostgreSQL Anonymizer is part of the [Dalibo Labs] initiative. It is mainly 
developed by [Damien Clochard].

This is an open project, contributions are welcome. We need your feedback and 
ideas ! Let us know what you think of this tool, how it fits your needs and 
what features are missing.

If you want to help, you can find a list of `Junior Jobs` here:

https://gitlab.com/dalibo/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs


[Dalibo Labs]: https://labs.dalibo.com
[Damien Clochard]: https://www.dalibo.com/en/equipe#daamien



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