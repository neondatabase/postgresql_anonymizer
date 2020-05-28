Various Masking Strategies
==============================================================================

The extension provides functions to implement 8 main anonymization strategies:

* [Destruction]
* [Adding Noise]
* [Shuffling]
* [Randomization]
* [Faking]
* [Pseudonymization]
* [Partial scrambling]
* [Generalization]

[Destruction]: #destruction
[Adding Noise]: #adding-noise
[Randomization]: #randomization
[Faking]: #faking
[Pseudonymization]: #pseudonymization
[Partial scrambling]: #partial-scrambling
[Generalization]: #generalization

Depending on your data, you may need to use different strategies on different
columns :

* For names and other 'direct identifiers' , [Faking] is often usefull
* [Shuffling] is convienient for foreign keys
* [Adding Noise] is interesting for numeric values and dates
* [Partial Scrambling] is perfect for email address and phone numbers
* etc.

Destruction
------------------------------------------------------------------------------

First of all, the fastest and safest way to anonymize a data is to destroy it
:-)

In many case, the best approach to hide the content of a column is to replace
all values with a single static value.

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
an original value by resquesting its masked value multiple times and then simply
use the `AVG()` function to get a close approximation. ( See
`demo/noise_reduction_attack.sql` for more details). In a nutshell, these
functions are best fitted for [Anonymous Dumps] and [In-Place Anonymization].
They should be avoided when using [Dynamic Masking].

[Anonymous Dumps]: anonymous_dumps/
[In-Place Anonymization]: in_place_anonymization/
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



Faking
------------------------------------------------------------------------------

The idea of **Faking** is to replace sensitive data with **random-but-plausible**
values. The goal is to avoid any identification from the data record while
remaining suitable for testing, data analysis and data processing.

In order to use the faking functions, you have to `load()` the extension
in your database first:

```sql
SELECT anon.load();
```

The `load()` function will charge a default dataset of random data ( lists
names, cities, etc. ). If you want to use your own dataset, you can load
custom CSV files with `load('/path/to/custom_cvs_files/')`

Once the fake data is loaded you have access to 12 faking functions:

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


Pseudonymization
------------------------------------------------------------------------------

Pseudonymization is similar to [Faking] in the sense that it generates
realistic values. The main difference is that the pseudonymization is
deterministic : the functions always will return the same fake value based
on a seed and an optional salt.

In order to use the faking functions, you have to `load()` the extension
in your database first:

```sql
SELECT anon.load();
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

The second argument is optional. You can call each function with only the
seed like this `anon.pseudo_city('bob')`. The salt is here to increase
complexity and avoid dictionnary and brute force attacks (see warning below).

The seed can be any information related to the subjet. For instance, we can
consistenty generate the same fake email address for a given person by using
her login as the seed :

```sql
SECURITY LABEL FOR anon
  ON COLUMN users.emailaddress
  IS 'MASKED WITH FUNCTION anon.pseudo_email(users.login) ';
```

**WARNING** : Pseudonymization is often confused with anonymization but in fact
they serve 2 different purposes. With pseudonymization, the real data can be
rebuild using the pseudo data, the masking rules and the seed. If an attacker
gets access to these 3 elements, he/she can easily re-identify some people
using `brute force` or `dictionnary` attacks. Therefore, you should protect any
pseudonymized data and your seeds with the same level of security that the original
dataset. The GDPR makes it very clear that personal data which have undergone
pseudonymization are still considered to be personnal information (see [Recital 26])

In a nutshell: pseudonymization may be usefull in some use cases. But if your
goal is to escape from GDPR or similar data regulation, it is clearly a bad solution.


[Recital 26]: https://www.privacy-regulation.eu/en/recital-26-GDPR.htm


Partial Scrambling
-------------------------------------------------------------------------------

**Partial scrambling** leaves out some part of the data.
For instance : a credit card number can be replaced by '40XX XXXX XXXX XX96'.

2 functions are available:

* `anon.partial('abcdefgh',1,'xxxx',3)` will return 'axxxxfgh';
* `anon.email('daamien@gmail.com')` will becomme 'da******@gm******.com'


Generalization
-------------------------------------------------------------------------------

Genelization is the principle of replace the original value by a range
containing this values. For instance, instead of saying 'Paul is 42 years old',
you would can say 'Paul is between 40 and 50 years old.

> The generalization functions are a data type transformation. Therefore it is
> not possible to use them with the dynamic masking engine. Hower they are
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

We can build a view upon this table to suppress some colums ( `SSN`
and `name` ) and generalize the zipcode and the birth date like
this:

```sql
CREATE VIEW anonymized_patient AS
SELECT
    'REDACTED' AS name,
    anon.generalize_int4range(zipcode,100) AS zipcode,
    anon.generalize_tsrange(birth,'decade') AS birth
    disease
FROM patients;
```

The anonymized table now look like that:

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
true but they are less accurante therefore reduce the risk of re-identification.

PostgreSQL offers several [RANGE] data types which are perfect for dates and
numeric values.

For numeric values, 3 functions are available

* `generalize_int4range(value, step)`
* `generalize_int8range(value, step)`
* `generalize_numrange(value, step)`

...where `value` is the data the will be generalized, `step` is the size of
each range.


[RANGE]: https://www.postgresql.org/docs/current/rangetypes.html


Write your own Masks !
------------------------------------------------------------------------------

You can also use you own functions as a mask. The function must either be
destructive (like [Partial Scrambling]) or insert some randomness in the dataset
(like [Faking]).

For instance, if you wrote a function `foo()`, you can apply it like this:

```sql
SECURITY LABEL FOR anon ON COLUMN player.score IS 'MASKED WITH FUNCTION foo()';
```

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
through the keys and replace the sensible values as needed.

[PostgreSQL JSON functions and operators]: https://www.postgresql.org/docs/current/functions-json.html

```sql
CREATE FUNCTION remove_last_name(j JSONB)
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
SELECT remove_last_name(info) FROM company;
```

When that's ok you can declare this function as the mask of
the `info` field:

```sql
SECURITY LABEL FOR anon ON COLUMN company.info
IS 'MASKED WITH FUNCTION remove_last_name(info)';
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

This is just a quick and dirty example. As you can see manipulating a
sophiticated JSON structure with SQL is possible but it can be tricky at
first! There are multiple ways of walking through the keys and updating
values. You will probably have to try different approaches depending on
your real JSON data and the performance you want ot reach.

