#!/bin/bash
#
#    pg_dump_anon
#    A basic wrapper to export anonymized data with pg_dump and psql
#
#    This is work in progress. Use with care.
#
#

usage()
{
cat << END
Usage: $(basename "$0") [OPTION]... [DBNAME]

General options:
  -f, --file=FILENAME           output file
  --help                        display this message

Options controlling the output content:
  -n, --schema=PATTERN          dump the specified schema(s) only
  -N, --exclude-schema=PATTERN  do NOT dump the specified schema(s)
  -t, --table=PATTERN           dump the specified table(s) only
  -T, --exclude-table=PATTERN   do NOT dump the specified table(s)
  --exclude-table-data=PATTERN  do NOT dump data for the specified table(s)

Connection options:
  -d, --dbname=DBNAME           database to dump
  -h, --host=HOSTNAME           database server host or socket directory
  -p, --port=PORT               database server port number
  -U, --username=NAME           connect as specified database user
  -w, --no-password             never prompt for password
  -W, --password                force password prompt (should happen automatically)

If no database name is supplied, then the PGDATABASE environment
variable value is used.

END
}

## Return the masking schema
get_mask_schema() {
$PSQL << EOSQL
  SELECT anon.mask_schema();
EOSQL
}

## Return the masking filters based on the table name
get_mask_filters() {
$PSQL << EOSQL
  SELECT anon.mask_filters('$1'::REGCLASS);
EOSQL
}

## There's no clean way to exclude an extension from a dump
## This is a pragmatic approach
filter_out_extension(){
grep -v -E "^-- Name: $1;" |
grep -v -E "^CREATE EXTENSION IF NOT EXISTS $1" |
grep -v -E "^-- Name: EXTENSION $1" |
grep -v -E "^COMMENT ON EXTENSION $1"
}

##
## M A I N
##

##
## pg_dump and psql have a lot of common parameters ( -h, -d, etc.) but they
## also have similar parameters with different names (e.g. `pg_dump -f` and
## `psql -o` ). This wrapper script allows a subset of pg_dump's parameters
## and when needed, we transform the pg_dump options into the matching psql
## options
##
stdout=/dev/stdout    # by default, use standard ouput
pg_dump_opt=          # backup args before parsing
psql_opt=     # connections options
exclude_table_data=   # dump the ddl, but ignore the data

while [ $# -gt 0 ]; do
    case "$1" in
    -d|--dbname)
        pg_dump_opt+=" $1"
        psql_connect_op+=" $1"
        shift
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    --dbname=*)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -f|--file)  # `pg_dump_anon -f foo.sql` becomes `pg_dump [...] > foo.sql`
        #skip the `-f` tag
        shift
        #psql_output_opt+=" $1"
        stdout=$1
        ;;
    --file=*) # `pg_dump_anon --file=foo.sql` becomes `pg_dump [...] > foo.sql`
        stdout=$1
        ;;
    -h|--host)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        shift
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    --host=*)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        shift
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -p|--port)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    --port=*)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -U|--username)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        shift
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    --username=*)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -w|--no-password)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -W|--password)
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    -n|--schema)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        shift
        pg_dump_opt+=" $1"
        ;;
    --schema=*)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        ;;
    -N|--exclude-schema)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        shift
        pg_dump_opt+=" $1"
        ;;
    --exclude-schema=*)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        ;;
    -t)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        shift
        pg_dump_opt+=" $1"
        ;;
    --table=*)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        ;;
    -T|--exclude-table)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        shift
        pg_dump_opt+=" $1"
        ;;
    --exclude-table=*)
        pg_dump_opt+=" $1"
        # ignore the option for psql
        ;;
    --exclude-table-data=*)
        pg_dump_opt+=" $1"
        exclude_table_data+=" $1"
        ;;
    --help)
        usage
        exit 0
        ;;
    -*|--*)
        echo "$0: Invalid option -- $1"
        echo Try "$0 --help" for more information.
        exit 1
        ;;
    *)
        # this is DBNAME
        pg_dump_opt+=" $1"
        psql_opt+=" $1"
        ;;
    esac
    shift
done

PSQL="psql $psql_opt --quiet --tuples-only --no-align"

## Stop if the extension is not installed in the database
version=$( $PSQL -c 'SELECT anon.version();' )
if [ -z "$version" ]
then
  echo 'ERROR: Anon extension is not installed in this database.' > /dev/stderr
  exit 1
fi

## Header
cat > "$stdout" <<EOF
--
-- Dump generated by PostgreSQL Anonymizer $version
--
EOF

##
## Dump the DDL
##
## We need to remove
##  - Security Labels (masking rules are confidential)
##  - The schemas installed by the anon extension
##  - the anon extension and its dependencies
##
##
exclude_anon_schemas="--exclude-schema=anon --exclude-schema=$(get_mask_schema)"
DUMP="pg_dump --schema-only --no-security-labels $exclude_anon_schemas $pg_dump_opt"

$DUMP | filter_out_extension anon | filter_out_extension tsm_system_rows >> "$stdout"

##
## We're launching the pg_dump again to get the list of the tables that were
## dumped. Only this time we add extra parameters like --exclude-table-data
##
exclude_tables=${exclude_table_data//--exclude-table-data=/--exclude-table=}
dumped_tables=$($DUMP ${exclude_tables[@]} |awk '/^CREATE TABLE /{ print $3 }')

##
## For each dumped table, we export the data form the Masking View
## instead of the real data
##
for t in $dumped_tables
do
  filters=$(get_mask_filters "$t")
  ## generate the "COPY ... FROM STDIN" statement for a given table
  echo "COPY $t FROM STDIN WITH CSV;" >> "$stdout"
  $PSQL -c "\copy (SELECT $filters FROM $t) TO STDOUT WITH CSV" >> "$stdout" || echo "... during export of $t" >&2
  echo \\.  >> "$stdout"
  echo  >> "$stdout"
done

##
## Let's dump the DDL again !
## This time we want to export only the sequences data, which must restored
## after the tables data.
## The trick here is to use `--exclude-table-data=*` instead of `--schema-only`
##

# shellcheck disable=SC2086
pg_dump --exclude-table-data=* $exclude_anon_schemas $pg_dump_opt | grep '^SELECT pg_catalog.setval' >> "$stdout"

