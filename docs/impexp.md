Import Export
===============================================================================

Principle
--------------------------------------------------------------------------------

Rules can be imported and exported in jsonb format via the functions :

* `anon.export_current_database_rules(provider text DEFAULT 'anon')`
* `anon.export_roles_rules(provider text DEFAULT 'anon')`
* `anon.import_database_rules(database_rules jsonb, provider text DEFAULT 'anon')`
* `anon.import_roles_rules(role_rules jsonb, provider text DEFAULT 'anon'`

Since roles are instance wide objects they must be managed separately.

Export
--------------------------------------------------------------------------------

We will create the following objects in the database **anon** to present the
feature.

```sql
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
ALTER DATABASE anon SET anon.masking_policies = 'impexp';
ALTER DATABASE anon SET session_preload_libraries=anon;
\c - -- reconnect

CREATE ROLE anna LOGIN;
CREATE SCHEMA test;
CREATE TABLE test.t1(c int, t text);
CREATE TABLE test.t2(c int, t text);
CREATE TABLE test.t3(c int, t text);
CREATE VIEW test.v AS SELECT * FROM test.t3;
SECURITY LABEL FOR impexp ON ROLE anna
                IS 'MASKED';
SECURITY LABEL FOR impexp ON SCHEMA test
                IS 'TRUSTED';
SECURITY LABEL FOR impexp ON TABLE test.t1
                IS 'MASKED WHEN c > 10';
SECURITY LABEL FOR impexp ON COLUMN test.t1.t
                IS 'MASKED WITH FUNCTION pg_catalog.md5(t)';
SECURITY LABEL FOR impexp ON COLUMN test.t2.t
                IS 'MASKED WITH VALUE NULL';
SECURITY LABEL FOR impexp ON VIEW test.v
                IS 'MASKED WHEN c > 10';
SECURITY LABEL FOR impexp ON COLUMN test.v.t
                IS 'MASKED WITH FUNCTION pg_catalog.md5(t)';
SECURITY LABEL FOR impexp ON FUNCTION pg_catalog.md5(text)
                IS 'TRUSTED';
```

Exporting all role rules for the `impexp` masking policy (details about the
format are described in the Import section of this page):

```sql
SELECT jsonb_pretty(x) FROM anon.export_roles_rules('impexp') AS F(x);
```

```text
        jsonb_pretty
-----------------------------
 {                          +
     "anna": "MASKED"+
 }
(1 row)
```

Export the current database's roles for the `impexp` provider:

```sql
SELECT jsonb_pretty(x) FROM anon.export_current_database_rules('impexp') AS F(x);
```

```text
                             jsonb_pretty
-----------------------------------------------------------------------
 {                                                                    +
     "schemas": {                                                     +
         "test": {                                                    +
             "mask": "TRUSTED",                                       +
             "views": {                                               +
                 "v": {                                               +
                     "mask": "MASKED WHEN c > 10",                    +
                     "columns": {                                     +
                         "t": "MASKED WITH FUNCTION pg_catalog.md5(t)"+
                     }                                                +
                 }                                                    +
             },                                                       +
             "tables": {                                              +
                 "t1": {                                              +
                     "mask": "MASKED WHEN c > 10",                    +
                     "columns": {                                     +
                         "t": "MASKED WITH FUNCTION pg_catalog.md5(t)"+
                     }                                                +
                 },                                                   +
                 "t2": {                                              +
                     "columns": {                                     +
                         "t": "MASKED WITH VALUE NULL"                +
                     }                                                +
                 }                                                    +
             }                                                        +
         },                                                           +
         "pg_catalog": {                                              +
             "functions": {                                           +
                 "pg_catalog.md5(text)": "TRUSTED"                    +
             }                                                        +
         }                                                            +
     }                                                                +
 }
(1 row)
```

If no masking policy is provided, `anon` is the default. In this case all the
masking policies will be exported, including thoses added by the extension
(functions in the `pg_catalog` or `anon` schema).

Import
--------------------------------------------------------------------------------

The import function take a json string and creates the security labels. All
objects must exist beforehand with the correct type.

A masking rule is a string.

The role rules are imported with `anon.import_roles_rules(rule, provider)`.
where `provier` is the masking policy and defaults to `anon` and  `rule` is a
json string composed of a hashmap where:

* each key is a role name;
* each object is a masking rule.

```sql
SELECT * FROM anon.import_roles_rules(
$$
{
    "anna": "MASKED"
}
$$, 'impexp'
);
```

The command outputs the `SECURITY LABEL` statements that where executed.

```text
INFO:  SECURITY LABEL FOR impexp ON ROLE anna IS $$ MASKED $$;
 import_roles_rules
--------------------

(1 row)
```

Note: This label is simplified for the example, in a production build the label
would containe random label (`label_295103987224690337673989110229554009196`).

For a database the json follows this schema:

* `mask`: an optionnal key, it contains the masking rule
* `schemas`:
   * `mask`: an optionnal key, it contains the masking rule
   * `functions`: an optionnal key, it contains a hasmap where:
      * each key is a valid function name, function with duplicate names should
        include the parameter list;
      * each object is a masking rule.
   * `tables`|`views`|`foreign tables`: optionnal keys key, each can contain
     a hasmap where:
      * each key is a valid relation name of the specified kind;
      * each object contains:
         * `mask`: an optionnal key, it contains the masking rule;
         * `columns`: a hashmap of columns where:
            * each key is a valid column name;
            * each object is a masking rule.

The security labels are created in the current database and the provided masking
policy (or `anon` otherwise) with the `anon.import_database_rules(rules,
provider)` function.

```sql
SELECT * FROM anon.import_database_rules(
$$
{
    "schemas": {
        "test": {
            "mask": "TRUSTED",
            "tables": {
                "t1": {
                    "mask": "MASKED WHEN c > 10",
                    "columns": {
                        "t": "MASKED WITH FUNCTION pg_catalog.md5(t)"
                    }
                },
                "t2": {
                    "columns": {
                        "t": "MASKED WITH VALUE NULL"
                    }
                }
            },
            "views": {
                "v": {
                    "mask": "MASKED WHEN c > 10",
                    "columns": {
                        "t": "MASKED WITH FUNCTION pg_catalog.md5(t)"
                    }
                }
            }
        },
        "pg_catalog": {
            "functions": {
                "pg_catalog.md5(text)": "TRUSTED"
            }
        }
    }
}
$$, 'impexp'
);
```

The command outputs the `SECURITY LABEL` statements that where executed.

```text
INFO:  SECURITY LABEL FOR impexp ON FUNCTION pg_catalog.md5(text) IS ↵
$$ TRUSTED $$;
INFO:  SECURITY LABEL FOR impexp ON SCHEMA test IS $$ TRUSTED $$;
INFO:  SECURITY LABEL FOR impexp ON TABLE "test"."t1" IS $$ MASKED WHEN ↵
c > 10 $$;
INFO:  SECURITY LABEL FOR impexp ON COLUMN "test"."t1"."t" IS $$ MASKED ↵
WITH FUNCTION pg_catalog.md5(t) $$;
INFO:  SECURITY LABEL FOR impexp ON COLUMN "test"."t2"."t" IS $$ MASKED ↵
WITH VALUE NULL $$;
INFO:  SECURITY LABEL FOR impexp ON VIEW "test"."v" IS $$ MASKED WHEN ↵
c > 10 $$;
INFO:  SECURITY LABEL FOR impexp ON COLUMN "test"."v"."t" IS $$ MASKED ↵
WITH FUNCTION pg_catalog.md5(t) $$;
FUNCTION pg_catalog.md5(t)';
 import_database_rules
-----------------------

(1 row)
```
