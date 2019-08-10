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
( 5,	'Michael Jordan',	32292    );

COMMENT ON COLUMN player.name IS 'MASKED WITH FUNCTION anon.fake_last_name()';
```

Limitations
------------------------------------------------------------------------------

If your columns already have comments, simply append the `MASKED WITH FUNCTION` 
statement at the end of the comment.

