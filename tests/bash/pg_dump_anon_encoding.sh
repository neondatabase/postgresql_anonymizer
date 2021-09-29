#!/bin/bash

PSQL=psql
SUPERUSER=postgres
DB_SOURCE=test_12343RDEFSDFSFQCDSFS
DB_TARGET=test_sFSFdvicsdfea232EDEF

# Prepare
createdb --encoding=LATIN9 $DB_SOURCE

$PSQL $DB_SOURCE << EOSQL
  CREATE EXTENSION anon CASCADE;
  CREATE TABLE people AS SELECT 'Éléonore' AS firstname;
  SECURITY LABEL FOR anon ON COLUMN people.firstname
  IS 'MASKED WITH VALUE ''Amédée'' ';
EOSQL

# Dump & Restore
createdb --encoding=UTF8 $DB_TARGET
./bin/pg_dump_anon.sh --encoding=UTF8 $DB_SOURCE | $PSQL $DB_TARGET

$PSQL $DB_TARGET << EOSQL
  SELECT firstname FROM people;
EOSQL

# clean up
dropdb $DB_SOURCE
dropdb $DB_TARGET

