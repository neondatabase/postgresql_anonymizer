#!/bin/sh

set -e

echo "shared_preload_libraries = 'anon'" >> /var/lib/postgresql/data/postgresql.conf

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

SQL="CREATE EXTENSION IF NOT EXISTS anon CASCADE;"

echo "Loading extension into template1 and postgres database"
psql --dbname="template1" -c "$SQL"
psql --dbname="postgres" -c "$SQL"

