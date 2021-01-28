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


