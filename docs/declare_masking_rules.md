Put on your Masks !
===============================================================================

The main idea of this extension is to offer **anonymization by design**.

The data masking rules should be written by the people who develop the
application because they have the best knowledge of how the data model works.
Therefore masking rules must be implemented directly inside the database schema.

This allows to mask the data directly inside the PostgreSQL instance without
using an external tool and thus limiting the exposure and the risks of data leak.

The data masking rules are declared simply by using [security labels]:

[security labels]: https://www.postgresql.org/docs/current/sql-security-label.html

<!-- demo/declare_masking_rules.sql -->

```sql
CREATE TABLE player( id SERIAL, name TEXT, points INT);

INSERT INTO player VALUES
  ( 1, 'Kareem Abdul-Jabbar', 38387),
  ( 5, 'Michael Jordan', 32292 );

SECURITY LABEL FOR anon ON COLUMN player.name
  IS 'MASKED WITH FUNCTION anon.fake_last_name()';

SECURITY LABEL FOR anon ON COLUMN player.id
  IS 'MASKED WITH VALUE NULL';
```

Escaping String literals
------------------------------------------------------------------------------

As you may have notice the masking rule definitions are placed between single
quotes. Therefore if you need to use a string inside a masking rule, you need
to use [C-Style escapes] like this:

```sql
SECURITY LABEL FOR anon ON COLUMN player.name
  IS E'MASKED WITH VALUE \'CONFIDENTIAL\'';
```

Or use [dollar quoting] which is easier to read

```sql
SECURITY LABEL FOR anon ON COLUMN player.name
  IS 'MASKED WITH VALUE $$CONFIDENTIAL$$';
```

[C-Style escapes]: https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE
[dollar quoting]: https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-DOLLAR-QUOTING


Using Expressions
------------------------------------------------------------------------------

You can use more advanced expressions with the `MASKED WITH VALUE` syntax:

```sql
SECURITY LABEL FOR anon ON COLUMN player.name
  IS 'MASKED WITH VALUE CASE WHEN name IS NULL
                             THEN $$John$$
                             ELSE anon.random_string(LENGTH(name))
                             END';
```


Removing a masking rule
------------------------------------------------------------------------------

You can simply erase a masking rule like this:

```sql
SECURITY LABEL FOR anon ON COLUMN player.name IS NULL;
```

To remove all rules at once, you can use:

```sql
SELECT anon.remove_masks_for_all_columns();
```

Limitations
------------------------------------------------------------------------------

* The masking rules are **NOT INHERITED** ! If you have split a table into
  multiple partitions, you need to declare the masking rules for each partition.


Declaring Rules with COMMENTs is deprecated
------------------------------------------------------------------------------

Previous version of the extension allowed users to declare masking rules using
the `COMMENT` syntax.

This is not suppported any more. `SECURITY LABELS` are now the only way to
declare rules.




