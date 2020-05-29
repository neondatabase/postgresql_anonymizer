#!/bin/bash
#
#    pg_dump_anon
#    A basic wrapper to export anonymized data with pg_dump and psql
#
#    This is work in progress. Use with care.
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
stdout=/dev/stdout      # by default, use standard ouput
pg_dump_opt=()          # export options
psql_opt=()             # connections options
exclude_table_data=()   # dump the ddl, but ignore the data

while [ $# -gt 0 ]; do
    case "$1" in
    -d|--dbname)
        shift
        pg_dump_opt+=("--dbname=$1")
        psql_opt+=("--dbname=$1")
        ;;
    --dbname=*)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
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
        shift
        pg_dump_opt+=("--host=$1")
        psql_opt+=("--host=$1")
        ;;
    --host=*)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    -p|--port)
        shift
        pg_dump_opt+=("--port=$1")
        psql_opt+=("--port=$1")
        ;;
    --port=*)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    -U|--username)
        shift
        pg_dump_opt+=("--username=$1")
        psql_opt+=("--username=$1")
        ;;
    --username=*)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    -w|--no-password)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    -W|--password)
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    -n|--schema)
        shift
        pg_dump_opt+=("--schema=$1")
        # ignore the option for psql
        ;;
    --schema=*)
        pg_dump_opt+=("$1")
        # ignore the option for psql
        ;;
    -N|--exclude-schema)
        shift
        pg_dump_opt+=("--exclude-schema=$1")
        # ignore the option for psql
        ;;
    --exclude-schema=*)
        pg_dump_opt+=("$1")
        # ignore the option for psql
        ;;
    -t|--table)
        shift
        pg_dump_opt+=("--table=$1")
        # ignore the option for psql
        ;;
    --table=*)
        pg_dump_opt+=("$1")
        # ignore the option for psql
        ;;
    -T|--exclude-table)
        shift
        pg_dump_opt+=("--exclude-table=$1")
        # ignore the option for psql
        ;;
    --exclude-table=*)
        pg_dump_opt+=("$1")
        # ignore the option for psql
        ;;
    --exclude-table-data=*)
        pg_dump_opt+=("$1")
        exclude_table_data+=("$1")
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
        pg_dump_opt+=("$1")
        psql_opt+=("$1")
        ;;
    esac
    shift
done

PSQL="psql ${psql_opt[*]} --quiet --tuples-only --no-align"

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


################################################################################
## 1. Dump the DDL
################################################################################

# gather all options needed to dump the DDL
ddl_dump_opt=()
ddl_dump_opt+=("${pg_dump_opt[@]}")     # options from the commande line
ddl_dump_opt+=("--schema-only")         # data will be dumped later
ddl_dump_opt+=("--no-security-labels")  # masking rules are confidential
ddl_dump_opt+=("--exclude-schema=anon") # do not dump the extension schema
ddl_dump_opt+=("--exclude-schema=$(get_mask_schema)") # idem

# we need to remove some `CREATE EXTENSION` commands
pg_dump "${ddl_dump_opt[@]}" \
| filter_out_extension anon  \
| filter_out_extension tsm_system_rows \
>> "$stdout"

################################################################################
## 2. Dump the tables data
##
## We need to know which table data must be dumped.
## So We're launching the pg_dump again to get the list of the tables that were
## dumped previously.
################################################################################

tables_dump_opt=()
tables_dump_opt+=("${ddl_dump_opt[@]}")  # same as previously

# Only this time, we exclude the tables listed in `--exclude-table-data`
tables_dump_opt+=(${exclude_table_data//--exclude-table-data=/--exclude-table=})

# List the tables whose data must be dumped
dumped_tables=$(
  pg_dump "${tables_dump_opt[@]}" \
  | awk '/^CREATE TABLE /{ print $3 }'
)

# For each dumped table, we export the data by applying the masking rules
for t in $dumped_tables
do
  # get the masking filters of this table (if any)
  filters=$(get_mask_filters "$t")
  # generate the "COPY ... FROM STDIN" statement for a given table
  echo "COPY $t FROM STDIN WITH CSV;" >> "$stdout"
  # export the data
  $PSQL -c "\copy (SELECT $filters FROM $t) TO STDOUT WITH CSV" \
    >> "$stdout" || echo "Error during export of $t" >&2
  # close the stdin stream
  echo \\.  >> "$stdout"
  echo  >> "$stdout"
done

################################################################################
## 3. Dump the sequences data
################################################################################

seq_data_dump_opt=()
seq_data_dump_opt+=(${pg_dump_opt[@]})        # options from the commande line
seq_data_dump_opt+=("--exclude-schema=anon")  # do not dump the anon sequences

# The trick here is to use `--exclude-table-data=*` instead of `--schema-only`
# this way we get the sequences data without the tables data
seq_data_dump_opt+=("--exclude-table-data=*")

pg_dump "${seq_data_dump_opt[@]}"   \
| grep '^SELECT pg_catalog.setval'  \
>> "$stdout"

