Custom Fake Data
==============================================================================

This extension is delivered with a small set of fake data by default. For each
fake function ( `fake_email()`, `fake_first_name()`) we provide only 1000 unique
values, and they are only in English.

Here's how you can create your own set of fake data!

Localized fake data
------------------------------------------------------------------------------

As an example, here's a python script that will generate fake data for you:

<https://gitlab.com/dalibo/postgresql_anonymizer/-/blob/master/python/populate.py>

To produce 5000 emails in French & German, you'd call the scripts like this:

```shell
populate.py --table email --locales fr,de --lines 5000
```

This will output the fake data in `CSV` format.

Use `populate.py --help` for more details about the script parameters.

You can load the fake data directly into the extension like this:

```sql
TRUNCATE anon.email;

COPY anon.email
FROM
PROGRAM 'populate.py --table email --locales fr,de --lines 5000';

SELECT setval('anon.email_oid_seq', max(oid))
FROM anon.email;

CLUSTER anon.email;
```

> **IMPORTANT** : This script is provided as an example, it is not
> officially supported.


Load your own fake data
------------------------------------------------------------------------------

If you want to use your own dataset, you can import custom CSV files with :

```sql
SELECT anon.init('/path/to/custom_csv_files/')
```

Look at the `data` folder to find the format of the CSV files.



Using the PostgreSQL Faker extension
------------------------------------------------------------------------------

If you need more specialized fake data sets, please read the [Advanced Faking]
section.

[Advanced Faking]: masking_functions.md#advanced-faking
