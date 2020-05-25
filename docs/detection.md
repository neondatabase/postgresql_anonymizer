Searching for Identifiers
===============================================================================

> WARNING : This is feature is at an early stage of development.

As we've seen previously, this extension makes it very easy to
[declare the masking rules].

[declare masking rules]: declare_masking_rules/

But of course when you're creating an anonymization strategy, the hard part is
to scan the database model to find which columns contains direct and indirect
identifiers and then decide how these identifiers should be masked.

The extension provides a `detect()` function that will search for common
identifiers names based on dictionary. For now, 2 dictionaries are available:
english ('en_US') and french ('fr_FR'). By default the english dictionary is
used:

```sql
# SELECT anon.detect('en_US');
 table_name |  column_name   | identifiers_category | direct
------------+----------------+----------------------+--------
 customer   | CreditCard     | creditcard           | t
 vendor     | Firstname      | firstname            | t
 customer   | firstname      | firstname            | t
 customer   | id             | account_id           | t
```

The identifiers categories are based on the [HIPAA classification].

[HIPAA classification]: https://www.luc.edu/its/aboutits/itspoliciesguidelines/hipaainformation/18hipaaidentifiers/

Limitations
---------------------------------------------------------------------------------

This is an heuristic method in the sense that it may report usefull information
but it is based on a pragmatic approach that can lead to detection mistakes,
especially:

* `false positive`: a column is reported as an identifiers but it is not.
* `false negative`: a column contains identifiers but it is not reported

The second one is of course more problematic. In any case, you should not
consider this function as an helping tool but aknowledge that you still need
to review the entire database model in search of hidden identifiers.
