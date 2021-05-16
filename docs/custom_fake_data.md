Custom Fake Data
==============================================================================

By default, this extension delivered with a small set of fake data. For each
fake function ( `fake_email()`, `fake_first_name()`) we provide pnly 1000 unique
values and they are only in English.

Here's how you can create your own set of fake data !

Localized fake data
------------------------------------------------------------------------------

We provide a python script that will generate fake data for you. This script
is located in the anon extension directory usually sometehing like

```shell
/usr/share/postgresql/13/extension/anon/populate.py
```

If you want to produce 5000 emails in French & German, you simply call the
scripts like this:

``` shell
$ python3 $(pg_config --sharedir)/extension/anon/populate.py --table email \
                                                             --locales fr,de \
                                                             --lines 5000
```

This will output the fake data in `CSV` format.

Use `populate.py --help` for more details about the script parameters

You can load directly the fake data into the extension like this:

```sql
TRUNCATE anon.email;

COPY anon.email
FROM
PROGRAM 'python3 [...]/populate.py --table email --locales fr,de --lines 5000';

SELECT setval('anon.email_oid_seq', max(oid))
FROM anon.email;

CLUSTER anon.email;
```


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

[Advanced Faking]: /masking_functions/#advanced-faking
