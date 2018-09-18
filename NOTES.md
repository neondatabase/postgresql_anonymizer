Development Notes
===============================================================================

Volatility
-------------------------------------------------------------------------------

Performances 
-------------------------------------------------------------------------------


1.  **ORDER BY random()** : Basic but very slow

```SQL
SELECT name FROM anon.last_name ORDER BY random() LIMIT 1;
```

2. **OFFSET floor()** :  

```SQL
SELECT name 
FROM anon.last_name 
OFFSET floor(random()*(SELECT count(*) FROM anon.last_name)) 
LIMIT 1;
```

3. **TABLESAMPLE** cannot return a specific number of rows

```SQL
SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM(1) LIMIT 1; 
```


4. **tsm-system-rows** 

```SQL
SELECT name FROM @extschema@.last_name TABLESAMPLE SYSTEM_ROWS(1);
```


__Links__

* <https://stackoverflow.com/questions/5297396/quick-random-row-selection-in-postgres/5298588#5298588>
* <https://blog.2ndquadrant.com/tablesample-in-postgresql-9-5-2/>
* <http://web.archive.org/web/20080214235745/http://www.powerpostgresql.com/Random_Aggregate>
* <https://www.postgresql.org/docs/current/static/tsm-system-rows.html>
