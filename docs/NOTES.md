Development Notes
===============================================================================

Support for PostgreSQL 9.5
-------------------------------------------------------------------------------

PostgeSQL 9.5 has 2 main issues for this extension :


* The pg_config table is called by the init() function but it was introduced
  in PG 9.6. You can simplify create a temporary pg_config table just before
  loading the extension:

  ```sql
  CREATE TEMPORARY TABLE pg_config AS
  SELECT 'SHAREDIR'::TEXT AS name,
         '/usr/share/postgresql/9.5'::TEXT AS setting
  ;
  ```

* The CASCADE option is not available with PG 9.5. So you need to load
  `tsm_system_rows` manually:

  ```sql
  CREATE EXTENSION IF NOT EXISTS tsm_system_rows;
  CREATE EXTENSION IF NOT EXISTS anon;
  ```


Building a C extension
-------------------------------------------------------------------------------

* https://www.postgresql.org/message-id/flat/CAJGNTeP%3D-6Gyqq5TN9OvYEydi7Fv1oGyYj650LGTnW44oAzYCg%40mail.gmail.com

Sampling Performances
-------------------------------------------------------------------------------


Test 1.  **ORDER BY random()** : Basic but very slow

```SQL
SELECT name FROM anon.last_name ORDER BY random() LIMIT 1;
```

Test 2. **OFFSET floor()** :

```SQL
SELECT name
FROM anon.last_name
OFFSET floor(random()*(SELECT count(*) FROM anon.last_name))
LIMIT 1;
```

Test 3. **TABLESAMPLE** cannot return a specific number of rows

```SQL
SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM(1) LIMIT 1;
```


Test 4. **tsm-system-rows**

```SQL
SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM_ROWS(1);
```


### Links

* <https://stackoverflow.com/questions/5297396/quick-random-row-selection-in-postgres/5298588#5298588>
* <https://blog.2ndquadrant.com/tablesample-in-postgresql-9-5-2/>
* <http://web.archive.org/web/20080214235745/http://www.powerpostgresql.com/Random_Aggregate>
* <https://www.postgresql.org/docs/current/static/tsm-system-rows.html>
