//    pg_dump_anon.go
//    A basic wrapper to export anonymized data with pg_dump and psql
//

package main

import (
  "flag"
  "fmt"
  "log"
  "os"
  "os/exec"
  "regexp"
  "strings"
//  "runtime"
)

//
// Global variables
//

// export options
var pg_dump_opts []string= []string{}

// client options
var psql_opts []string = []string {
  "--quiet",
  "--tuples-only",
  "--no-align",
  "--no-psqlrc",
}

// Return the masking schema
func get_maskschema() string {
  return psql_to_string("SELECT pg_catalog.current_setting('anon.maskschema');")
}

// Return the masking filters based on the table name
func get_mask_filters(tablename string) string {
  query := fmt.Sprintf("SELECT anon.mask_filters('%s'::REGCLASS);", tablename)
  return psql_to_string(query)
}

// There's no clean way to exclude an extension from a dump
// This is a pragmatic approach
func filter_out_extension(ddl_lines string, extension string) string {

  exclude_lines := []string {
    fmt.Sprintf("-- Name: %s;.*\n", extension),
    fmt.Sprintf("CREATE EXTENSION IF NOT EXISTS %s .*\n", extension),
    fmt.Sprintf("-- Name: EXTENSION %s;.*\n", extension),
    fmt.Sprintf("COMMENT ON EXTENSION %s .*\n", extension)}

  for i := range exclude_lines {
    re := regexp.MustCompile(exclude_lines[i])
    ddl_lines=re.ReplaceAllString(ddl_lines, "")
  }
  return ddl_lines
}

func psql_to_string(query string) string {
  args := []string { fmt.Sprintf("--command=%s", query) }
//  if runtime.GOOS == "windows" {
//    args[0] = fmt.Sprintf("--command=\"%s\"",query)
//  }
  args=append(args,psql_opts...)
  cmd := exec.Command("psql",args...)  // #nosec G204
  output, err := cmd.Output()
  if err != nil {
    log.Println(cmd.Args)
    log.Fatal(string(err.(*exec.ExitError).Stderr))
  }
  result := string(output)
  result = strings.TrimSuffix(result,"\r\n"); // windows
  result = strings.TrimSuffix(result,"\n");   // linux
  return result
}

func psql(query string, output *os.File) {
  args := []string { fmt.Sprintf("--command=%s", query) }
  args=append(args,psql_opts...)
  cmd := exec.Command("psql",args...)  // #nosec G204
  cmd.Stdout = output
  _ = cmd.Run()
}

func pg_dump_to_array(options []string) []byte {
  cmd := exec.Command("pg_dump",options...)  // #nosec G204
  output, err := cmd.Output()
  if err != nil {
    log.Println(cmd.Args)
    log.Fatal(string(err.(*exec.ExitError).Stderr))
  }
  return output
}

func pg_dump(options []string, output *os.File) {
  cmd := exec.Command("pg_dump",options...)  // #nosec G204
  cmd.Stdout = output
  cmd.Stderr = output
  _ = cmd.Run()
}

// option_value is optional
func append_option(option_flag string, option_value ...string) {
  if len(option_value) > 0 {
    if option_value[0] != "" {
      append_psql_option(option_flag,option_value[0])
      append_pg_dump_option(option_flag,option_value[0])
    }
  } else {
    append_psql_option(option_flag)
    append_pg_dump_option(option_flag)
  }
}

// option_value is optional
func append_psql_option(option_flag string, option_value ...string) {
  if len(option_value) > 0 && option_value[0] != "" {
    if option_value[0] != "" {
      psql_opts = append(psql_opts,option_flag+option_value[0])
    }
  } else {
    psql_opts = append(psql_opts,option_flag)
  }
}

// option_value is optional
func append_pg_dump_option(option_flag string, option_value ...string) {
  if len(option_value) > 0 {
    if option_value[0] != "" {
      pg_dump_opts = append(pg_dump_opts,option_flag+option_value[0])
    }
  } else {
    pg_dump_opts = append(pg_dump_opts,option_flag)
  }
}


func main() {

//
// Basic checks
//
  _ , err_psql := exec.LookPath("psql")
  if err_psql != nil {
    log.Fatal("Can't find psql, check your PATH")
  }

  _ , err_pg_dump := exec.LookPath("pg_dump")
  if err_pg_dump != nil {
    log.Fatal("Can't find pg_dump, check your PATH")
  }

//
// 0. Parsing the command line arguments
//
// pg_dump_anon supports a subset of pg_dump options
//
// some arguments will be pushed to `pg_dump` and/or `psql` while others need
// specific treatment ( especially the `--file` option)
//

  output := os.Stdout       // by default, use standard ouput


  exclude_table_data := ""  // dump the ddl, but ignore the data

  // all allowed flags
  exclude_table_dataPtr := flag.String("exclude-table-data","",
                                "do NOT dump data for the specified table(s)")

  dPtr := flag.String("d","","database to dump")
  dbnamePtr := flag.String("dbname", "", "database to dump")

  EPtr := flag.String("E","","dump the data in encoding ENCODING")
  encodingPtr := flag.String("encoding","","dump the data in encoding ENCODING")

  hPtr := flag.String("h", "", "hostname")
  hostPtr := flag.String("host", "", "hostname")

  pPtr := flag.String("p", "", "port")
  portPtr := flag.String("port", "", "port")

  UPtr := flag.String("U","","username")
  usernamePtr := flag.String("username","","username")

  wPtr := flag.Bool("w",false,"never prompt for password")
  no_passwordPtr := flag.Bool("no-password",false,"never prompt for password")

  WPtr := flag.Bool("W",false,"force password prompt")
  passwordPtr := flag.Bool("password",false,"force password prompt")

  nPtr := flag.String("n","","Dump the specified schema(s) only")
  schemaPtr := flag.String("schema","","Dump the specified schema(s) only")

  NPtr := flag.String("N","","Exclude the specified schema(s)")
  excludeschemaPtr := flag.String("exclude-schema","","Exclude the specified schema(s)")

  tPtr := flag.String("t","","Dump the specified table(s) only")
  tablePtr := flag.String("table","","Dump the specified table(s) only")

  TPtr := flag.String("T","","Exclude the specified table(s)")
  excludetablePtr := flag.String("exclude-table","","Exclude the specified schema(s)")

  flag.Parse()

  // DBNAME
  append_option("--dbname=",*dPtr)
  append_option("--dbname=",*dbnamePtr)

  // Encoding
  append_pg_dump_option("--encoding=",*EPtr)
  append_pg_dump_option("--encoding=",*encodingPtr)

  // PGHOST
  append_option("--host=",*hPtr)
  append_option("--host=",*hostPtr)

  // PORT
  append_option("--port=",*pPtr)
  append_option("--port=",*portPtr)

  // USER
  append_option("--username=",*UPtr)
  append_option("--username=",*usernamePtr)

  if *wPtr || *no_passwordPtr {
    append_option("--no-password")
  }

  if *WPtr || *passwordPtr {
    append_option("--password")
  }

//    # output options
//    # `pg_dump_anon -f foo.sql` becomes `pg_dump [...] > foo.sql`
//    -f|--file)
//        shift # skip the `-f` tag
//        output="$1"
//        ;;
//    --file=*)
//        output="${1#--file=}"
//        ;;
  append_pg_dump_option("--schema=",*nPtr)
  append_pg_dump_option("--schema=",*schemaPtr)
  append_pg_dump_option("--exclude-schema=",*NPtr)
  append_pg_dump_option("--exclude-schema=",*excludeschemaPtr)
  append_pg_dump_option("--table=",*tPtr)
  append_pg_dump_option("--table=",*tablePtr)
  append_pg_dump_option("--exclude-table=",*TPtr)
  append_pg_dump_option("--exclude-table=",*excludetablePtr)

  if *exclude_table_dataPtr != "" {
    exclude_table_data = *exclude_table_dataPtr
    pg_dump_opts = append(pg_dump_opts,
                            "--exclude_table_data="+exclude_table_data)
  }

  // If there's a last remaining argument, it is DBNAME
  for i := range flag.Args() {
    append_option(flag.Arg(i))
  }


  // Stop if the extension is not installed in the database
  version := string(psql_to_string("SELECT anon.version()"))
  if version == "" {
    log.Fatal("Anon extension is not installed in this database.")
  }

  // Header
  fmt.Println("--")
  fmt.Println(fmt.Sprintf("-- Dump generated by PostgreSQL Anonymizer %s",
              version))
  fmt.Println("--")


//##############################################################################
//## 1. Dump the DDL (pre-data section)
//##############################################################################

  // gather all options needed to dump the DDL
  exclude_mask_schema := fmt.Sprintf("--exclude-schema=%s",get_maskschema())
  ddl_dump_opt := []string{
    "--section=pre-data",                 // data will be dumped later
    "--no-security-labels",               // masking rules are confidential
    "--exclude-schema=anon",              // do not dump the extension schema
    exclude_mask_schema }
  pre_data := pg_dump_to_array(append(ddl_dump_opt,pg_dump_opts...))

  // We need to remove some `CREATE EXTENSION` commands
  pre_data_filtered := string(pre_data)
  pre_data_filtered = filter_out_extension(pre_data_filtered,"anon")
  pre_data_filtered = filter_out_extension(pre_data_filtered,"pgcrypto")
  pre_data_filtered = filter_out_extension(pre_data_filtered,"tsm_system_rows")
  fmt.Println(pre_data_filtered)

//##############################################################################
//## 2. Dump the tables data
//##
//## We need to know which table data must be dumped.
//## So We're launching the pg_dump again to get the list of the tables that were
//## dumped previously.
//##############################################################################


  // Only this time, we exclude the tables listed in `--exclude-table-data`
//  tables_dump_opt := pg_dump_opts
//  tables_dump_opt = append(tables_dump_opt,"")
//  ${exclude_table_data//--exclude-table-data=/--exclude-table=}
//}
//TODO

  // List the tables whose data must be dumped
  re := regexp.MustCompile(`CREATE TABLE (.*) \(`)
  dumped_tables := re.FindAllSubmatch(pre_data,-1)

  // For each dumped table, we export the data by applying the masking rules
  for _, t := range dumped_tables {
    // get the masking filters of this table (if any)
    tablename := string(t[1]) // FindAllSubmatch returns 2 values for each match
    //generate the "COPY ... FROM STDIN" statement for a given table
    fmt.Printf("COPY %s FROM STDIN WITH CSV;\n",tablename)
    // export the data
    copy_query := fmt.Sprintf(
      "\\copy (SELECT %s FROM %s) TO STDOUT WITH CSV",
      get_mask_filters(tablename),
      tablename)
    psql(copy_query, output) // no newline required
    // close the stdin stream
    fmt.Println("\\.")
    fmt.Println("")
  }


//##############################################################################
//## 3. Dump the sequences data
//##############################################################################

  // extract the names of all sequences
  seq_query := `
    SELECT string_agg('--table='||sequence_name,',')
    FROM information_schema.sequences
    WHERE sequence_schema != 'anon';`

  seq_table_opts := strings.Split(psql_to_string(seq_query),",")

  // strings.Split returns {""} when nothings is found
  if seq_table_opts[0] != "" {
    // we only want the `setval` lines
    seq_data_dump_opts := []string{"--data-only"}
    seq_data_dump_opts = append(seq_data_dump_opts,seq_table_opts...)
    seq_data_dump_opts = append(seq_data_dump_opts,pg_dump_opts...)
    pg_dump(seq_data_dump_opts, output)
  }

//##############################################################################
//## 4. Dump the DDL (post-data section)
//##############################################################################

  post_data_dump_opts := []string{
    "--section=post-data",
    "--no-security-labels",  // masking rules are confidential
    "--exclude-schema=anon", // do not dump the extension schema
    exclude_mask_schema }    // define at the pre-data step

  pg_dump(append(post_data_dump_opts,pg_dump_opts...), output)
  os.Exit(0)
}

