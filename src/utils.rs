///
/// # Useful functions
///

use crate::compat;
use pgrx::prelude::*;
use pgrx::PgSqlErrorCode::*;
use std::ffi::CStr;
use std::ffi::CString;

//----------------------------------------------------------------------------
// Public functions
//----------------------------------------------------------------------------

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
        ereport!(
            ERROR,
            ERRCODE_INVALID_NAME,
            format!("function call is empty")
        );
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
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(raw_parsetree_list, 0)
            as *mut pg_sys::RawStmt
        )
    };

    let stmt = unsafe {
        PgBox::from_pg( raw_stmt.stmt as *mut pg_sys::SelectStmt )
    };

    let restarget = unsafe {
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(stmt.targetList, 0)
            as *mut pg_sys::ResTarget
        )
    };

    if !unsafe { pgrx::is_a(restarget.val, pg_sys::NodeTag::T_FuncCall) } {
        ereport!(
            ERROR,
            ERRCODE_INVALID_NAME,
            format!("'{function_call}' is not a valid function call")
        );
    }

    // if the function name is qualified, extract and return the schema name
    // https://github.com/postgres/postgres/blob/master/src/include/nodes/parsenodes.h#L413
    let fc = unsafe {
        PgBox::from_pg(restarget.val as *mut pg_sys::FuncCall)
    };

    // fc.funcname is a pointer to a pg_sys::List
    let funcname = unsafe {
        PgBox::from_pg(fc.funcname)
    };

    if funcname.length == 2 {
        // the function name is qualified, the first element of the list
        // is the schema name
        let schema_val = unsafe {
            PgBox::from_pg(
                pg_sys::pgrx_list_nth(funcname.as_ptr(), 0)
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

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::utils::*;

    #[pg_test]
    fn test_get_function_schema() {
        assert_eq!("a",get_function_schema("a.b()".to_string()));
        assert_eq!("", get_function_schema("publicfoo()".to_string()));
    }

    #[pg_test(error = "function call is empty")]
    fn test_get_function_schema_error_empty() {
        get_function_schema("".to_string());
    }

    #[pg_test(error = "'foo' is not a valid function call")]
    fn test_get_function_schema_error_invalid() {
        get_function_schema("foo".to_string());
    }
}
