///
/// # Useful functions
///

use crate::compat;
use crate::error;
use crate::macros;
use pgrx::prelude::*;
use std::ffi::CStr;
use std::ffi::CString;
use std::ffi::c_char;

//----------------------------------------------------------------------------
// Public functions
//----------------------------------------------------------------------------

/// Returns the 1-based number of a column in a table
///
pub fn get_column_number(
    relid: pg_sys::Oid,
    attname: &str
) -> Option<i16> {
    let lockmode = pg_sys::AccessShareLock as i32;

    // `pg_sys::relation_open()` will raise XX000
    // if the specified oid isn't a valid relation
    let relation = unsafe {
        PgBox::from_pg(pg_sys::relation_open(relid, lockmode))
    };

    // reldesc is a TupleDescData object
    // https://doxygen.postgresql.org/structTupleDescData.html
    let reldesc = unsafe { PgBox::from_pg(relation.rd_att) };
    let natts = reldesc.natts;
    let attrs = unsafe {
        reldesc.attrs.as_slice(natts.try_into().unwrap())
    };

    let mut result: Option<i16> = None;
    for a in attrs {
        if a.attisdropped {
            continue;
        }
        if macros::NameDataStr(a.attname) == attname {
            result=Some(a.attnum);
        }
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }
    result
}


/// Returns the 1-based numbers of all the columns in a table
///
pub fn get_column_numbers(
    relid: pg_sys::Oid
) -> Option<Vec<i16>> {
    let lockmode = pg_sys::AccessShareLock as i32;

    // `pg_sys::relation_open()` will raise XX000
    // if the specified oid isn't a valid relation
    let relation = unsafe {
        PgBox::from_pg(pg_sys::relation_open(relid, lockmode))
    };

    // reldesc is a TupleDescData object
    // https://doxygen.postgresql.org/structTupleDescData.html
    let reldesc = unsafe { PgBox::from_pg(relation.rd_att) };
    let natts = reldesc.natts;
    let attrs = unsafe {
        reldesc.attrs.as_slice(natts.try_into().unwrap())
    };

    let mut result = vec![];
    for a in attrs {
        if a.attisdropped {
            continue;
        }
        result.push(a.attnum);
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }
    Some(result)
}

/// Given a function call (e.g. 'anon.fake_city()'), return the namespace
/// the function (e.g. 'anon') if possible
///
/// * returns the schema name if the function is properly schema-qualified
/// * returns an empty string if we can't find the schema name
///
/// We're calling the parser to split the function call into a "raw parse tree".
/// At this stage, there's no way to know if the schema does really exists. We
///  simply deduce the schema name as it is provided.
///
pub fn get_function_schema(function_call: String) -> String {

    if function_call.is_empty() {
        error::function_call_is_empty().ereport();
    }

    // build a simple SELECT statement and parse it
    let query_string = format!("SELECT {function_call}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let raw_parsetree_list = unsafe {
        compat::raw_parser(
            query_c_string.as_c_str().as_ptr() as *const pgrx::ffi::c_char
        )
    };

    // walk through the parse tree, down to the FuncCall node (if present)
    let raw_stmt = unsafe {
        // this is the equivalent of the linitial_node C macro
        // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
        PgBox::<pg_sys::RawStmt>::from_pg(
            pg_sys::list_nth(raw_parsetree_list, 0)
            as *mut pg_sys::RawStmt
        )
    };

    let stmt = unsafe {
        PgBox::<pg_sys::SelectStmt>::from_pg(
            raw_stmt.stmt as *mut pg_sys::SelectStmt
        )
    };

    let restarget = unsafe {
        PgBox::<pg_sys::ResTarget>::from_pg(
            pg_sys::list_nth(stmt.targetList, 0)
            as *mut pg_sys::ResTarget
        )
    };

    if !unsafe { pgrx::is_a(restarget.val, pg_sys::NodeTag::T_FuncCall) } {
        error::function_is_not_valid(&function_call).ereport();
    }

    // if the function name is qualified, extract and return the schema name
    // https://github.com/postgres/postgres/blob/master/src/include/nodes/parsenodes.h#L413
    let fc = unsafe {
        PgBox::<pg_sys::FuncCall>::from_pg(restarget.val as *mut pg_sys::FuncCall)
    };

    // fc.funcname is a pointer to a pg_sys::List
    let funcname = unsafe {
        PgBox::<pg_sys::List>::from_pg(fc.funcname)
    };

    if funcname.length == 2 {
        // the function name is qualified, the first element of the list
        // is the schema name
        let schema_val = unsafe {
            PgBox::from_pg(
                pg_sys::list_nth(funcname.as_ptr(), 0)
                as *mut compat::SchemaValue
            )
        };
        let schema_c_ptr = unsafe{compat::strVal(*schema_val)};
        let schema_c_str = unsafe {CStr::from_ptr(schema_c_ptr)};
        return schema_c_str.to_str().unwrap().to_string();
    }

    // found nothing, so return an empty string
    "".to_string()
}

/// Returns the full name of a relation
///
pub fn get_relation_qualified_name(relid: pg_sys::Oid ) -> Option<String>
{
    if ! macros::OidIsValid(relid) { return None; }

    let namespace_ptr = unsafe {
        pg_sys::get_namespace_name(pg_sys::get_rel_namespace(relid))
    };
    if namespace_ptr.is_null() { return None; }

    let relname_ptr = unsafe { pg_sys::get_rel_name(relid) };
    Some(format!(   "{}.{}",
                    quote_identifier(namespace_ptr),
                    quote_identifier(relname_ptr)
    ))
}


/// Check if a relation belongs in the `anon` namespace
///
pub fn is_anon_relation_oid(relid: pg_sys::Oid) -> bool
{
    use crate::ANON;
    unsafe {
        pg_sys::get_rel_namespace(relid)
        ==
        pg_sys::get_namespace_oid(ANON.as_ptr(),false)
    }
}

/// Return the quoted name of a string
/// if a schema is named `WEIRD_schema`, its quoted name is `"WEIRD_schema"`
///
pub fn quote_identifier(ident: *const c_char) -> &'static str {
    return unsafe { CStr::from_ptr(pg_sys::quote_identifier(ident)) }
        .to_str()
        .unwrap();
}


/// Return the quoted name of a NameData identifier
/// if a column is named `I`, its quoted name is `"I"`
///
pub fn quote_name_data(name_data: &pg_sys::NameData) -> &str {
    quote_identifier(name_data.data.as_ptr() as *const c_char)
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::utils::*;
    use crate::fixture;

    #[pg_test]
    fn test_get_column_number() {
        let relid = fixture::create_table_person();
        assert_eq!(Some(2 as i16), get_column_number(relid, "firstname"));
        assert_eq!(Some(3 as i16), get_column_number(relid, "lastname"));
        // dropped column
        assert_eq!(None, get_column_number(relid, "pronouns"));
        assert_eq!(None,get_column_number(relid, "does_not_exist"));
    }

    #[pg_test(error="could not open relation with OID 21")]
    fn test_get_column_number_fail() {
        let invalid_relid = pg_sys::Oid::from(21);
        assert_eq!(None,get_column_number(invalid_relid, "does_not_exist"));
    }

    #[pg_test]
    fn test_get_column_numbers() {
        let relid = fixture::create_table_person();
        assert_eq!(Some(vec![2, 3]), get_column_numbers(relid));
    }

    #[pg_test(error="could not open relation with OID 21")]
    fn test_get_column_numbers_fail() {
        let invalid_relid = pg_sys::Oid::from(21);
        assert_eq!(None,get_column_numbers(invalid_relid));
    }

    #[pg_test]
    fn test_get_function_schema() {
        assert_eq!("a",get_function_schema("a.b()".to_string()));
        assert_eq!("", get_function_schema("publicfoo()".to_string()));
    }

    #[pg_test(error = "Anon: function call is empty")]
    fn test_get_function_schema_error_empty() {
        get_function_schema("".to_string());
    }

    #[pg_test(error = "Anon: 'foo' is not a valid function call")]
    fn test_get_function_schema_error_invalid() {
        get_function_schema("foo".to_string());
    }

    #[pg_test]
    fn test_get_relation_qualified_name_invalid_oid() {
        assert!(get_relation_qualified_name(pg_sys::InvalidOid).is_none());
        assert!(get_relation_qualified_name(99999.into()).is_none());
    }

    #[pg_test]
    fn test_get_relation_qualified_name() {
        let person_relid = fixture::create_table_person();
        assert_eq!(
            Some("public.person".to_string()),
            get_relation_qualified_name(person_relid)
        );
        let location_relid = fixture::create_table_location();
        assert_eq!(
            Some("\"Postal_Info\".location".to_string()),
            get_relation_qualified_name(location_relid)
        );
    }

    #[pg_test]
    fn test_is_anon_relation_oid() {
        assert!(! is_anon_relation_oid(pg_sys::InvalidOid));

        let person_relid = fixture::create_table_person();
        assert!(! is_anon_relation_oid(person_relid));

        let last_name_relid = Spi::get_one::<pg_sys::Oid>(
            "SELECT 'anon.last_name'::REGCLASS::OID;"
        ).unwrap()
         .expect("should be an OID");
        assert!(is_anon_relation_oid(last_name_relid));
    }

    #[pg_test]
    fn test_quote_identifier() {
        let schema_c_string = CString::new("WEIRD_schema").unwrap();
        let schema_c_ptr = schema_c_string.as_c_str().as_ptr() as *const c_char;
        assert_eq!("\"WEIRD_schema\"",quote_identifier(schema_c_ptr));
    }
}
