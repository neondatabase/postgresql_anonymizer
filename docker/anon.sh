#!/usr/bin/env bash

PGDATA=/var/lib/postgresql/data/

{
mkdir -p $PGDATA
chown postgres $PGDATA
gosu postgres initdb
gosu postgres pg_ctl start
gosu postgres psql -c "ALTER SYSTEM SET session_preload_libraries = 'anon';"
gosu postgres psql -c "SELECT pg_reload_conf();"

cat | gosu postgres psql
} &> /dev/null

gosu postgres bin/pg_dump_anon.sh -U postgres

