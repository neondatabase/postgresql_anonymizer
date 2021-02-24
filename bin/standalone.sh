#!/bin/bash
#

##
## 0. Input variables
##

# $1 is the name of the output file

# EXTSCHEMA is the name of the schema where we install the required extensions
EXTSCHEMA=${EXTSCHEMA:-public}

##
## 1. Insert the CREATE EXTENSION commands before the anon code base
##
{
  echo "CREATE EXTENSION IF NOT EXISTS tsm_system_rows SCHEMA $EXTSCHEMA;"
  echo "CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA $EXTSCHEMA;"
  echo 'CREATE SCHEMA anon;'
  # Insert the extension content
  cat anon.sql
} >  "$1"


##
## 2. Remove PGXS specific code
##
sed -i 's/^SELECT pg_catalog.pg_extension_config_dump(.*//' "$1"
sed -i "s/@extschema@/$EXTSCHEMA/g" "$1"

##
## 3. Add the data loading commands
##
{
  echo "\\copy anon.city FROM 'data/default/city.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.city','oid'), max(oid)) FROM anon.city;"
  echo "\\copy anon.company FROM 'data/default/company.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.company','oid'), max(oid)) FROM anon.company;"
  echo "\\copy anon.email FROM 'data/default/email.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.email','oid'), max(oid)) FROM anon.email;"
  echo "\\copy anon.first_name FROM 'data/default/first_name.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.first_name','oid'), max(oid)) FROM anon.first_name;"
  echo "\\copy anon.iban FROM 'data/default/iban.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.iban','oid'), max(oid)) FROM anon.iban;"
  echo "\\copy anon.last_name FROM 'data/default/last_name.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.last_name','oid'), max(oid)) FROM anon.last_name;"
  echo "\\copy anon.siret FROM 'data/default/siret.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.siret','oid'), max(oid)) FROM anon.siret;"
  echo "\\copy anon.lorem_ipsum FROM 'data/default/lorem_ipsum.csv';"
  echo "SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('anon.lorem_ipsum','oid'), max(oid)) FROM anon.lorem_ipsum;"
  echo "\\copy anon.identifiers_category FROM 'data/default/identifiers_category.csv';"
  echo "\\copy anon.identifier FROM 'data/default/identifier_fr_FR.csv';"
  echo "\\copy anon.identifier FROM 'data/default/identifier_en_US.csv';"
  echo "SELECT COALESCE(anon.get_secret_salt(), anon.set_secret_salt(md5(random()::TEXT)));"
  echo "SELECT COALESCE(anon.get_secret_algorithm(), anon.set_secret_algorithm('sha512'));"
} >> "$1"
