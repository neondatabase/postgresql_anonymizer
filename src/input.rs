use crate::compat;
use crate::masking;
use crate::guc;
use crate::macros;
use crate::re;
use pgrx::prelude::*;
use std::ffi::CStr;
use std::ffi::CString;


/// check that an expression is a valid masking function
///
pub fn check_function( expr: &str) -> Result<(),&'static str> {

    let func = parse_expression(expr)?;

    if ! unsafe {
        pgrx::is_a(func.as_ptr(),pg_sys::NodeTag::T_FuncCall)
    } {
        return Err("Expression is not a function");
    }

    if ! guc::ANON_RESTRICT_TO_TRUSTED_SCHEMAS.get() { return Ok(()); }

    // Walk through the parse tree and check that the function itself and
    // all other functions used as parameters belong to a trusted schema.
    // The goal is to block privilege escalation attacks using something like:
    //
    // `MASKED WITH FUNCTION pg_catalog.upper(public.elevate())`
    //

    if has_untrusted_schema(func.as_ptr(),std::ptr::null_mut()) {
        return Err("At least one function belongs in an untrusted schema");
    }
    Ok(())

}

/// Validate a tablesample expression
///
pub fn check_tablesample( expr: &str ) -> Result<(),&'static str> {

    if expr.is_empty() {
        return Err("Expression is empty");
    }

    let query_string = format!("SELECT 1 FROM foo {expr}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();

    let raw_parsetree_list = PgTryBuilder::new(||
        Some(unsafe {
            compat::raw_parser(
                query_c_string.as_c_str().as_ptr()
                as *const pgrx::ffi::c_char
            )
        }))
        .catch_others(|_| None)
        .execute();

    // Only one statement in the parsetree is allowed
    if raw_parsetree_list.is_none()
    || raw_parsetree_list.unwrap().is_null()
    || unsafe { raw_parsetree_list.unwrap().as_ref().unwrap().length > 1 } {
        return Err("Expression is invalid");
    }

    Ok(())
}

/// check that an expression is a valid masking value
///
pub fn check_value( expr: &str) -> Result<(),&'static str> {
    let val = parse_expression(expr)?;
    if unsafe {
        ! val.is_null()
        && ( pgrx::is_a(val.as_ptr(),pg_sys::NodeTag::T_ColumnRef)
             || pgrx::is_a(val.as_ptr(),pg_sys::NodeTag::T_A_Const)
           )
    } { return Ok(()); }
    Err("Expression is invalid")
}


/// walk through a parsetree and check that all fonction belong in a trusted
/// schema
///
#[pg_guard]
extern "C" fn has_untrusted_schema(
    node: *mut pg_sys::Node,
    context: *mut ::core::ffi::c_void
) -> bool {

    if node.is_null() { return false ; }

    if unsafe {
        pgrx::is_a(node,pg_sys::NodeTag::T_FuncCall)
    } {
        let fc = unsafe {
            PgBox::from_pg(node as *mut pg_sys::FuncCall)
        };
        // fc.funcname is a pointer to a pg_sys::List
        let funcname = unsafe {
            PgBox::from_pg(fc.funcname)
        };

        // if the function name is not qualified, we can't trust it
        if funcname.length != 2 { return true; }

        // Now we know the function name is qualified,
        // the first element of the list is the schema name
        let schema_val = unsafe {
            PgBox::from_pg(
                pg_sys::pgrx_list_nth(funcname.as_ptr(), 0)
                as *mut compat::SchemaValue
            )
        };
        let schema_c_ptr = unsafe{ compat::strVal(*schema_val) };

        let namespaceId = unsafe {
                pg_sys::get_namespace_oid(schema_c_ptr,false)
        };

        // Returning true will stop the tree walker right away
        // So the logic is inverted: we stop the search once an unstrusted
        // schema is found.
        if ! is_trusted_namespace(namespaceId,"anon") { return true; }
    }

    unsafe {
        pg_sys::raw_expression_tree_walker( node,
                                            Some(has_untrusted_schema),
                                            context)
    }
}

/// Check that schema is trusted
///
fn is_trusted_namespace(namespace_id: pg_sys::Oid, policy: &str) -> bool
{
    if ! macros::OidIsValid(namespace_id) { return false };

    if let Some(seclabel) = masking::rule(
        pg_sys::NamespaceRelationId,
        namespace_id,
        0,
        policy
    ) {
        if seclabel.is_null() { return false; }
        let seclabel_cstr = unsafe { CStr::from_ptr(seclabel.as_ptr()) };
        return re::is_match_trusted(seclabel_cstr);
    }

    false
}

/// Parse a given expression and return its raw statement
///
fn parse_expression(expr: &str) -> Result<PgBox<pg_sys::Node>,&'static str>
{
    if expr.is_empty() {
        return Err("Expression is empty");
    }

    let query_string = format!("SELECT {expr}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let raw_parsetree_list = PgTryBuilder::new(||
        Some(unsafe {
            compat::raw_parser(
                query_c_string.as_c_str().as_ptr()
                as *const pgrx::ffi::c_char
            )
        }))
        .catch_others(|_| None)
        .execute();

    // Only one statement in the parsetree is allowed
    if raw_parsetree_list.is_none()
    || raw_parsetree_list.unwrap().is_null()
    || unsafe { raw_parsetree_list.unwrap().as_ref().unwrap().length > 1 } {
        return Err("Expression is invalid");
    }

    let raw_stmt = unsafe {
        // this is the equivalent of the linitial_node C macro
        // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(raw_parsetree_list.unwrap(), 0)
            as *mut pg_sys::RawStmt
        )
    };

    let stmt = unsafe {
        PgBox::from_pg( raw_stmt.stmt as *mut pg_sys::SelectStmt )
    };

    // Only one expression in the target is allowed
    if unsafe { stmt.targetList.as_ref().unwrap().length > 1 } {
        return Err("Expression is invalid");
    }

    let restarget = unsafe {
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(stmt.targetList, 0)
            as *mut pg_sys::ResTarget
        )
    };

    Ok(unsafe { PgBox::from_pg( restarget.val ) })
}


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::tests::fixture;
    use crate::input::*;

    #[pg_test]
    fn test_check_function(){
        let _gotham = fixture::create_trusted_schema();
        let _arkham = fixture::create_untrusted_schema();
        assert!(check_function("foo()").is_err());
        assert!(check_function("pg_catalog.foo()").is_err());
        assert!(check_function("anon.foo(pg_catalog.bar())").is_err());
        assert!(check_function("anon.foo()").is_ok());
        assert!(check_function("anon.foo(anon.bar())").is_ok());
        assert!(check_function("gotham.foo()").is_ok());
        assert!(check_function("arkham.foo()").is_err());
        assert!(check_function("").is_err());
        assert!(check_function("foo(), bar()").is_err());
        assert!(check_function("Robert'); DROP TABLE Students;--").is_err());
    }

    #[pg_test]
    fn test_check_tablesample(){
        assert!(check_tablesample("TABLESAMPLE SYSTEM(10)").is_ok());
        assert!(check_tablesample("").is_err());
        assert!(check_tablesample("TABLESAMPLE SYSTEM(10); DROP TABLE Students;--").is_err());
    }

    #[pg_test]
    fn test_check_value(){
        assert!(check_value("foo()").is_err());
        assert!(check_value("CAST(0 AS INT)").is_err());
        assert!(check_value("1").is_ok());
        assert!(check_value("a").is_ok());
        assert!(check_value("NULL").is_ok());
        assert!(check_value("").is_err());
    }

    #[pg_test]
    fn test_is_trusted_namespace(){
        let gotham = fixture::create_trusted_schema();
        let arkham = fixture::create_untrusted_schema();
        assert!(is_trusted_namespace(gotham,"anon"));
        assert!(!is_trusted_namespace(arkham,"anon"));
        assert!(!is_trusted_namespace(0.into(),"anon"));
    }

    #[pg_test]
    fn test_parse_expression(){
        assert!(parse_expression("a").is_ok());
        assert!(parse_expression("foo()").is_ok());
        assert!(parse_expression("NULL").is_ok());
        assert!(parse_expression("").is_err());
        assert!(parse_expression("a,b,c").is_err());
        assert!(parse_expression("Robert'); DROP TABLE Students;--").is_err());
    }

}
