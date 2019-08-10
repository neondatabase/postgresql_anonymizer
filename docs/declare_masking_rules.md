Put on your Masks !
===============================================================================

The main idea of this extension is to offer **anonymization by design**.

The data masking rules should be written by the people who develop the 
application because they have the best knowledge of how the data model works.
Therefore masking rules must be implemented directly inside the database schema.

This allows to mask the data directly inside the PostgreSQL instance without 
using an external tool and thus limiting the exposure and the risks of data leak.

The data masking rules are declared simply by using the `COMMENT` syntax :

<!-- demo/declare_masking_rules.sql -->

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.load();

CREATE TABLE player( id SERIAL, name TEXT, points INT);

INSERT INTO player VALUES  
( 1, 'Kareem Abdul-Jabbar',	38387),
( 5, 'Michael Jordan', 32292 );

COMMENT ON COLUMN player.name IS 'MASKED WITH FUNCTION anon.fake_last_name()';
```

Data Type Conversion
------------------------------------------------------------------------------

The various masking functions will return a certain data types. For instance:

* the faking functions (e.g.`fake_email()`) will return values in `TEXT` data 
  types
* the random functions will return `TEXT`, `INTEGER` or `TIMESTAMP WITH TIMEZONE`
* etc.

If the column you want to mask is in another data type (for instance `VARCHAR(30)`) 
then you need to add an explicit cast directly in the `COMMENT` declaration,
like this:

```sql
=# COMMENT ON COLUMN clients.family_name 
-# IS 'MASKED WITH FUNCTION anon.fake_last_name()::VARCHAR(30)';
```


Limitations
------------------------------------------------------------------------------

If your columns already have comments, simply append the `MASKED WITH FUNCTION` 
statement at the end of the comment.

