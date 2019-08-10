Anonymous Dumps
===============================================================================

Due to the core design of this extension, you cannot use `pg_dump` with a masked 
user. If you want to export the entire database with the anonymized data, you 
must use the `anon.dump()` function.


<!-- demo/dump.sql-->

Let's use a basic example :

```sql
CREATE TABLE cluedo ( name TEXT, weapon TEXT, room TEXT);

INSERT INTO cluedo VALUES
('Colonel Mustard','Candlestick', 'Kitchen'),
('Professor Plum', 'Revolver', 'Ballroom'),
('Miss Scarlett', 'Dagger', 'Lounge'),
('Mrs. Peacock', 'Rope', 'Dining Room');

SELECT * FROM cluedo;
```

Then load the extension:

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.load();
```

Now declare the masking rules

```sql
COMMENT ON COLUMN cluedo.name IS 'MASKED WITH FUNCTION anon.random_last_name()';
```

You can now export the anonymized data with :

```sql
SELECT anon.dump();
```

If you want to write the SQL dump directly into a file, you can call the 
function from the command line with :

```console
$ psql [...] -qtA -c 'SELECT anon.dump()' your_dabatase > dump.sql
```

NB: The `-qtA` flags are required.



