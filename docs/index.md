
![PostgreSQL Anonymizer](https://gitlab.com/dalibo/postgresql_anonymizer/raw/master/images/png_RVB/PostgreSQL-Anonymizer_H_couleur.png)


Anonymization & Data Masking for PostgreSQL
===============================================================================

`postgresql_anonymizer` is an extension to mask or replace
[personally identifiable information] (PII) or commercially sensitive data from
a PostgreSQL database.

The projet has a **declarative approach** of anonymization. This means you can
[declare the masking rules] using the PostgreSQL Data Definition Language (DDL)
and specify your anonymization strategy inside the table definition itself.

Once the maskings rules are defined, you can access the anonymized data in 3
different ways :

* [Anonymous Dumps] : Simply export the masked data into an SQL file
* [In-Place Anonymization] : Remove the PII according to the rules
* [Dynamic Masking] : Hide PII only for the masked users


In addition, various [Masking Functions] are available : randomization, faking,
partial scrambling, shufflin, noise or even your own custom function !

Beyond masking, it is also possible to use a 4th approach called [Generalization] 
which is perfect for statictics and data analytics. 

Finally the extension offers a panel of [detection] functions that will try to
guess which columns needs to be anonymized.

[INSTALL.md]: INSTALL/
[Concepts]: concepts/
[personally identifiable information]: https://en.wikipedia.org/wiki/Personally_identifiable_information
[declare the masking rules]: declare_masking_rules/

[Anonymous Dumps]: anonymous_dumps/
[In-Place Anonymization]: in_place_anonymization/
[Dynamic Masking]: dynamic_masking/
[Masking Functions]: masking_functions/



Example
------------------------------------------------------------------------------

```sql
=# SELECT * FROM people;
 id | fistname | lastname |   phone
----+----------+----------+------------
 T1 | Sarah    | Conor    | 0609110911
```

Step 1 : Activate the dynamic masking engine

```sql
=# CREATE EXTENSION IF NOT EXISTS anon CASCADE;
=# SELECT anon.start_dynamic_masking();
```

Step 2 : Declare a masked user

```sql
=# CREATE ROLE skynet LOGIN;
=# SECURITY LABEL FOR anon ON ROLE skynet IS 'MASKED';
```

Step 3 : Declare the masking rules

```sql
=# SECURITY LABEL FOR anonON COLUMN people.lastname
-# IS 'MASKED WITH FUNCTION anon.fake_last_name()';

=# SECURITY LABEL FOR anon ON COLUMN people.phone
-# IS 'MASKED WITH FUNCTION anon.partial(phone,2,$$******$$,2)';
```

Step 4 : Connect with the masked user

```sql
=# \! psql peopledb -U skynet -c 'SELECT * FROM people;'
 id | fistname | lastname  |   phone
----+----------+-----------+------------
 T1 | Sarah    | Stranahan | 06******11
```


Warning
------------------------------------------------------------------------------

> *This is projet is at an early stage of development and should used carefully.*

We need your feedback and ideas ! Let us know what you think of this tool,how it
fits your needs and what features are missing.

You can either [open an issue] or send a message at <contact@dalibo.com>.

[open an issue]: https://gitlab.com/dalibo/postgresql_anonymizer/issues



