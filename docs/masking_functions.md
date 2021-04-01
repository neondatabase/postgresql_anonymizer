Various Masking Strategies
==============================================================================

The extension provides functions to implement 8 main anonymization strategies:

* [Destruction]
* [Adding Noise]
* [Randomization]
* [Faking]
* [Advanced Faking]
* [Pseudonymization]
* [Generic Hashing]
* [Partial scrambling]
* [Generalization]

[Destruction]: #destruction
[Adding Noise]: #adding-noise
[Randomization]: #randomization
[Faking]: #faking
[Advanced Faking]: #advanced_faking
[Pseudonymization]: #pseudonymization
[Generic Hashing]: #generic-hashing
[Partial scrambling]: #partial-scrambling
[Generalization]: #generalization
[Shuffling]: /static_masking#shuffling

Depending on your data, you may need to use different strategies on different
columns :

* For names and other 'direct identifiers' , [Faking] is often useful
* [Shuffling] is convenient for foreign keys
* [Adding Noise] is interesting for numeric values and dates
* [Partial Scrambling] is perfect for email address and phone numbers
* etc.

Destruction
------------------------------------------------------------------------------

First of all, the fastest and safest way to anonymize a data is to destroy it
:-)

In many cases, the best approach to hide the content of a column is to replace
all the values with a single static value.

For instance, you can replace a entire column by the word 'CONFIDENTIAL' like
this:

```sql
SECURITY LABEL FOR anon
  ON COLUMN users.address
  IS 'MASKED WITH VALUE ''CONFIDENTIAL'' ';
```


Adding Noise
------------------------------------------------------------------------------

This is also called **Variance**. The idea is to "shift" dates and numeric
values. For example, by applying a +/- 10% variance to a salary column, the
dataset will remain meaningful.

* `anon.noise(original_value,ratio)` where original_value can be an `integer`,
  a `bigint` or a `double precision`. If the ratio is 0.33, the return value
  will be the original value randomly shifted with a ratio of +/- 33%

* `anon.noise(original_value, interval)` where original_value can be a date or a
  timestamp. If interval = '2 days', the return value will be the original value
  randomly shifted by +/- 2 days

**WARNING** : The `noise()` masking functions are vulnerable to a form of
repeat attack, especially with [Dynamic Masking]. A masked user can guess
an original value by requesting its masked value multiple times and then simply
use the `AVG()` function to get a close approximation. (See
`demo/noise_reduction_attack.sql` for more details). In a nutshell, these
functions are best fitted for [Anonymous Dumps] and [Static Masking].
They should be avoided when using [Dynamic Masking].

[Anonymous Dumps]: anonymous_dumps/
[Static Masking]: static_masking/
[Dynamic Masking]: dynamic_masking/




Randomization
------------------------------------------------------------------------------

The extension provides a large choice of function to generate purely random
data :

* `anon.random_date()` returns a date
* `anon.random_date_between(d1,d2)` returns a date between `d1` and `d2`
* `anon.random_int_between(i1,i2)` returns an integer between `i1` and `i2`
* `anon.random_bigint_between(b1,b2)` returns a bigint between `b1` and `b2`
* `anon.random_string(n)` returns a TEXT value containing `n` letters
* `anon.random_zip()` returns a 5-digit code
* `anon.random_phone(p)` returns a 8-digit phone with `p` as a prefix
* `anon.random_in(ARRAY[1,2,3])` returns an element of an INT array
* `anon.random_in(ARRAY['a','b','c'])` returns an element of a TEXT array



Faking
------------------------------------------------------------------------------

The idea of **Faking** is to replace sensitive data with **random-but-plausible**
values. The goal is to avoid any identification from the data record while
remaining suitable for testing, data analysis and data processing.

In order to use the faking functions, you have to `init()` the extension
in your database first:

```sql
SELECT anon.init();
```

The `init()` function will import a default dataset of random data (iban,
names, cities, etc.).

If you want to use your own dataset, you can import custom CSV files with :

```sql
SELECT init('/path/to/custom_csv_files/')
```

Once the fake data is loaded, you have access to 12 faking functions:

* `anon.fake_first_name()` returns a generic first name
* `anon.fake_last_name()` returns a generic last name
* `anon.fake_email()` returns a valid email address
* `anon.fake_city()` returns an existing city
* `anon.fake_city_in_country(c)` returns a city in country `c`
* `anon.fake_region()` returns an existing region
* `anon.fake_region_in_country(c)` returns a region in country `c`
* `anon.fake_country()` returns a country
* `anon.fake_company()` returns a generic company name
* `anon.fake_iban()` returns a valid IBAN
* `anon.fake_siret()` returns a valid SIRET
* `anon.fake_siren()` returns a valid SIREN

For TEXT and VARCHAR columns, you can use the classic [Lorem Ipsum] generator:

* `anon.lorem_ipsum()` returns 5 paragraphs
* `anon.lorem_ipsum(2)` returns 2 paragraphs
* `anon.lorem_ipsum( paragraphs := 4 )` returns 4 paragraphs
* `anon.lorem_ipsum( words := 20 )` returns 20 words
* `anon.lorem_ipsum( characters := 7 )` returns 7 characters

[Lorem Ipsum]: https://lipsum.com

Advanced Faking
------------------------------------------------------------------------------

Generating fake data is a complex topic. The functions provided here are
limited to basic use case. For more advanced faking methods, in particular
if you are looking for **localized fake data**, take a look at
[PostgreSQL Faker], a extension based upon the well-known [Faker python library].

[PostgreSQL Faker]: https://gitlab.com/dalibo/postgresql_faker
[Faker python library]: https://faker.readthedocs.io

This extension provides an advanced faking engine with localisation support

For example:

```sql
CREATE SCHEMA faker;
CREATE EXTENSION faker SCHEMA faker;
SELECT faker.faker('de_DE');
SELECT faker.first_name_female();
 first_name_female
-------------------
 Mirja
```

Pseudonymization
------------------------------------------------------------------------------

Pseudonymization is similar to [Faking] in the sense that it generates
realistic values. The main difference is that the pseudonymization is
deterministic : the functions always will return the same fake value based
on a seed and an optional salt.

In order to use the faking functions, you have to `init()` the extension
in your database first:

```sql
SELECT anon.init();
```

Once the fake data is loaded you have access to 10 pseudo functions:

* `anon.pseudo_first_name('seed','salt')` returns a generic first name
* `anon.pseudo_last_name('seed','salt')` returns a generic last name
* `anon.pseudo_email('seed','salt')` returns a valid email address
* `anon.pseudo_city('seed','salt')` returns an existing city
* `anon.pseudo_region('seed','salt')` returns an existing region
* `anon.pseudo_country('seed','salt')` returns a country
* `anon.pseudo_company('seed','salt')` returns a generic company name
* `anon.pseudo_iban('seed','salt')` returns a valid IBAN
* `anon.pseudo_siret('seed','salt')` returns a valid SIRET
* `anon.pseudo_siren('seed','salt')` returns a valid SIREN

The second argument ("salt") is optional. You can call each function with
only the seed like this `anon.pseudo_city('bob')`. The salt is here to increase
complexity and avoid dictionary and brute force attacks (see warning below).
If a salt is not given, a random secret salt is used instead
(see the [Generic Hashing] section for more details)

The seed can be any information related to the subject. For instance, we can
consistently generate the same fake email address for a given person by using
her login as the seed :

```sql
SECURITY LABEL FOR anon
  ON COLUMN users.emailaddress
  IS 'MASKED WITH FUNCTION anon.pseudo_email(users.login) ';
```

**NOTE** : You may want to produce unique values using a pseudonymization
function. For instance, if you want to mask an `email` column that is declared
as `UNIQUE`. In this case, you will need to initialize the extension with a fake
dataset that is **way bigger** than the numbers of rows of the table. Otherwise you
may see some "collisions" happening, i.e. two different original values producing
the same pseudo value.

**WARNING** : Pseudonymization is often confused with anonymization but in fact
they serve 2 different purposes. With pseudonymization, the real data can be
rebuild using the pseudo data, the masking rules and the seed. If an attacker
gets access to these 3 elements, he/she can easily re-identify some people
using `brute force` or `dictionary` attacks. Therefore, you should protect any
pseudonymized data and your seeds with the same level of security that the original
dataset. The GDPR makes it very clear that personal data which have undergone
pseudonymization are still considered to be personnel information (see [Recital 26])

In a nutshell: pseudonymization may be useful in some use cases. But if your
goal is to comply with GDPR or similar data regulation, it is clearly a bad solution.


[Recital 26]: https://www.privacy-regulation.eu/en/recital-26-GDPR.htm

Generic hashing
-------------------------------------------------------------------------------

In theory, hashing is not a valid anonymization technique, however in practice
it is sometimes necessary to generate a determinist hash of the original data.

For instance, when a pair of  primary key / foreign key is a "natural key",
it may contain actual information ( like a customer number containing a birth
date or something similar).

Hashing such columns allows to keep referential integrity intact even for
relatively unusual source data. Therefore, the

* `anon.hash(value)`  will return a text hash of the value using a secret salt
  and a secret hash algorithm (see below)

* `anon.digest(value,salt,algorithm)` lets you choose a salt, and a hash algorithm
  from a pre-defined list

By default, a random secret salt is generated when the extension is
initialized,
and the default hash algorithm is `sha512`. You can change these for the entire
database with two functions:

* `anon.set_secret_salt(value)` to define you own salt
* `anon.set_secret_algorithm(value)` to select another hash function.
  Possible values are: md5, sha1, sha224, sha256, sha384 or sha512

Keep in mind that hashing is a form a [Pseudonymization]. This means that the
real data can be rebuilt using the hashed value and the masking function. If an
attacker gets access to these elements, he or she can easily re-identify
some persons using `brute force` or `dictionary` attacks. Therefore, **the
salt and the algorithm used to hash the data must be protected with the
same level of security that the original dataset.**

In a nutshell, we recommend that you use the `anon.hash()` function rather than
`anon.digest()` because the salt will not appear clearly in the masking rule.

Furthermore: in practice the hash function will return a long string of character
like this:

```sql
SELECT anon.hash('bob');
                                  hash
----------------------------------------------------------------------------------------------------------------------------------
95b6accef02c5a725a8c9abf19ab5575f99ca3d9997984181e4b3f81d96cbca4d0977d694ac490350e01d0d213639909987ef52de8e44d6258d536c55e427397
```

For some columns, this may be too long and you may have to cut some parts the
hash in order to fit into the column. For instance, if you have a foreign key
based on a phone number and the column is a VARCHAR(12) you can transform the
data like this:

```sql
SECURITY LABEL FOR anon ON COLUMN people.phone_number
IS 'MASKED WITH FUNCTION pg_catalog.left(anon.hash(phone_number),12)';

SECURITY LABEL FOR anon ON COLUMN call_history.fk_phone_number
IS 'MASKED WITH FUNCTION pg_catalog.left(anon.hash(fk_phone_number),12)';
```

Of course, cutting the hash value to 12 characters will increase the risk
of "collision" (2 different values having the same fake hash). In such
case, it's up to you to evaluate this risk.



Partial Scrambling
-------------------------------------------------------------------------------

**Partial scrambling** leaves out some part of the data.
For instance : a credit card number can be replaced by '40XX XXXX XXXX XX96'.

2 functions are available:

* `anon.partial('abcdefgh',1,'xxxx',3)` will return 'axxxxfgh';
* `anon.partial_email('daamien@gmail.com')` will become 'da******@gm******.com'


Generalization
-------------------------------------------------------------------------------

Generalization is the principle of replacing the original value by a range
containing this values. For instance, instead of saying 'Paul is 42 years old',
you would say 'Paul is between 40 and 50 years old'.

> The generalization functions are a data type transformation. Therefore it is
> not possible to use them with the dynamic masking engine. However they are
> useful to create anonymized views. See example below

Let's imagine a table containing health information

```sql
SELECT * FROM patient;
 id |   name   |  zipcode |   birth    |    disease
----+----------+----------+------------+---------------
  1 | Alice    |    47678 | 1979-12-29 | Heart Disease
  2 | Bob      |    47678 | 1959-03-22 | Heart Disease
  3 | Caroline |    47678 | 1988-07-22 | Heart Disease
  4 | David    |    47905 | 1997-03-04 | Flu
  5 | Eleanor  |    47909 | 1999-12-15 | Heart Disease
  6 | Frank    |    47906 | 1968-07-04 | Cancer
  7 | Geri     |    47605 | 1977-10-30 | Heart Disease
  8 | Harry    |    47673 | 1978-06-13 | Cancer
  9 | Ingrid   |    47607 | 1991-12-12 | Cancer
```

We can build a view upon this table to suppress some columns ( `SSN`
and `name` ) and generalize the zipcode and the birth date like
this:

```sql
CREATE VIEW anonymized_patient AS
SELECT
    'REDACTED' AS lastname,
    anon.generalize_int4range(zipcode,100) AS zipcode,
    anon.generalize_tsrange(birth,'decade') AS birth
    disease
FROM patients;
```

The anonymized table now looks like that:

```sql
SELECT * FROM anonymized_patient;
 lastname |   zipcode     |           birth             |    disease
----------+---------------+-----------------------------+---------------
 REDACTED | [47600,47700) | ["1970-01-01","1980-01-01") | Heart Disease
 REDACTED | [47600,47700) | ["1950-01-01","1960-01-01") | Heart Disease
 REDACTED | [47600,47700) | ["1980-01-01","1990-01-01") | Heart Disease
 REDACTED | [47900,48000) | ["1990-01-01","2000-01-01") | Flu
 REDACTED | [47900,48000) | ["1990-01-01","2000-01-01") | Heart Disease
 REDACTED | [47900,48000) | ["1960-01-01","1970-01-01") | Cancer
 REDACTED | [47600,47700) | ["1970-01-01","1980-01-01") | Heart Disease
 REDACTED | [47600,47700) | ["1970-01-01","1980-01-01") | Cancer
 REDACTED | [47600,47700) | ["1990-01-01","2000-01-01") | Cancer
```


The generalized values are still useful for statistics because they remain
true, but they are less accurate, and therefore reduce the risk of
re-identification.

PostgreSQL offers several [RANGE] data types which are perfect for dates and
numeric values.

For numeric values, 3 functions are available

* `generalize_int4range(value, step)`
* `generalize_int8range(value, step)`
* `generalize_numrange(value, step)`

...where `value` is the data that will be generalized, and `step` is the size of
each range.


[RANGE]: https://www.postgresql.org/docs/current/rangetypes.html


Write your own Masks !
------------------------------------------------------------------------------

You can also use your own function as a mask. The function must either be
destructive (like [Partial Scrambling]) or insert some randomness in the dataset
(like [Faking]).

For instance if you wrote a function `foo()` inside the schema `bar`,
then you can apply it like this:

```sql
SECURITY LABEL FOR anon ON COLUMN player.score
IS 'MASKED WITH FUNCTION bar.foo()';
```

> NOTE: If `anon.restrict_to_trusted_schema` is enabled, then you need to add
> the `bar` schema in the `anon.trusted_schema` parameter.

### Example: Writing a masking function for a JSONB column

<!-- cf. demo/writing_your_own_mask.sql -->

For complex data types, you may have to write you own function. This will be
a common use case if you have to hide certain parts of a JSON field.

For example:

```sql
CREATE TABLE company (
  business_name TEXT,
  info JSONB
)
```

The `info` field contains unstructured data like this:

```sql
SELECT jsonb_pretty(info) FROM company WHERE business_name = 'Soylent Green';
           jsonb_pretty
----------------------------------
 {
     "employees": [
         {
             "lastName": "Doe",
             "firstName": "John"
         },
         {
             "lastName": "Smith",
             "firstName": "Anna"
         },
         {
             "lastName": "Jones",
             "firstName": "Peter"
         }
     ]
 }
(1 row)
```

Using the [PostgreSQL JSON functions and operators], you can walk
through the keys and replace the sensitive values as needed.

[PostgreSQL JSON functions and operators]: https://www.postgresql.org/docs/current/functions-json.html

```sql
CREATE FUNCTION custom_masks.remove_last_name(j JSONB)
RETURNS JSONB
VOLATILE
LANGUAGE SQL
AS $func$
SELECT
  json_build_object(
    'employees' ,
    array_agg(
      jsonb_set(e ,'{lastName}', to_jsonb(anon.fake_last_name()))
    )
  )::JSONB
FROM jsonb_array_elements( j->'employees') e
$func$;
```

Then check that the function is working correctly:

```sql
SELECT custom_masks.remove_last_name(info) FROM company;
```

When that's ok you can declare this function as the mask of
the `info` field:

```sql
SECURITY LABEL FOR anon ON COLUMN company.info
IS 'MASKED WITH FUNCTION custom_masks.remove_last_name(info)';
```

And try it out !

```sql
# SELECT anonymize_table('company');
# SELECT jsonb_pretty(info) FROM company WHERE business_name = 'Soylent Green';
            jsonb_pretty
-------------------------------------
 {
     "employees": [                 +
         {                          +
             "lastName": "Prawdzik",+
             "firstName": "John"    +
         },                         +
         {                          +
             "lastName": "Baltazor",+
             "firstName": "Anna"    +
         },                         +
         {                          +
             "lastName": "Taylan",  +
             "firstName": "Peter"   +
         }                          +
     ]                              +
 }
(1 row)
```

This is just a quick and dirty example. As you can see, manipulating a
sophisticated JSON structure with SQL is possible, but it can be tricky at
first! There are multiple ways of walking through the keys and updating
values. You will probably have to try different approaches, depending on
your real JSON data and the performance you want to reach.

