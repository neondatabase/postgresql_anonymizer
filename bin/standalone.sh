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
  echo "\\copy anon.company FROM 'data/default/company.csv';"
  echo "\\copy anon.email FROM 'data/default/email.csv';"
  echo "\\copy anon.first_name FROM 'data/default/first_name.csv';"
  echo "\\copy anon.iban FROM 'data/default/iban.csv';"
  echo "\\copy anon.last_name FROM 'data/default/last_name.csv';"
  echo "\\copy anon.siret FROM 'data/default/siret.csv';"
  echo "\\copy anon.lorem_ipsum FROM 'data/default/lorem_ipsum.csv';"
  echo "\\copy anon.identifiers_category FROM 'data/default/identifiers_category.csv';"
  echo "\\copy anon.identifier FROM 'data/default/identifier_fr_FR.csv';"
  echo "\\copy anon.identifier FROM 'data/default/identifier_en_US.csv';"
} >> "$1"
