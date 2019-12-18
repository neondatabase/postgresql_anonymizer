#! /bin/bash

IMG=registry.gitlab.com/dalibo/postgresql_anonymizer
BOX="docker run --rm -i $IMG /anon.sh"

# Create a demo database
createdb blackbox_demo_db

# Create a table
psql blackbox_demo_db -c "CREATE TABLE people(fistname TEXT,lastname TEXT)"

# Add data
psql blackbox_demo_db -c "INSERT INTO people VALUES ('Sarah', 'Conor');"

# Write the masking rules
cat <<EOF >> blackbox_rules.sql
SELECT pg_catalog.set_config('search_path', 'public', false);

CREATE EXTENSION anon CASCADE;
SELECT anon.load();

SECURITY LABEL FOR anon ON COLUMN people.lastname
IS 'MASKED WITH FUNCTION anon.fake_last_name()';
EOF

# Pass the dump and the rules throught the docker "black box"
pg_dump blackbox_demo_db | cat - blackbox_rules.sql | $BOX | grep 'Sarah'

# drop the demo database
dropdb blackbox_demo_db
