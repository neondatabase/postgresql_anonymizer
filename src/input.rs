use crate::compat;
use crate::error;
use crate::masking;
use crate::guc;
use crate::macros;
use crate::re;
use pgrx::prelude::*;
use std::ffi::CStr;
use std::ffi::CString;
use std::os::raw::c_char;

#[derive(PartialEq, Eq)]
#[derive(Clone)]
struct InputError(u32);

const ERROR_UNKNOWN              : InputError = InputError(0);
const ERROR_SCHEMA_NOT_TRUSTED   : InputError = InputError(1);
const ERROR_FUNCTION_UNTRUSTED   : InputError = InputError(2);
const ERROR_FUNCTION_UNQUALIFIED : InputError = InputError(3);

///
/// A context for the `is_untrusted` recursive function
///
struct CheckContext {
    policy: &'static str,
    error_code: Option<InputError>
}

impl CheckContext {
    fn new(policy: &'static str) -> CheckContext {
        CheckContext {
            policy,
            error_code: None
        }
    }
}

/// check that an expression is a valid masking function
///
pub fn check_function( expr: &str, policy: &'static str)
-> Result<(), String> {

    let Ok(func) = parse_expression(expr) else {
        return Err(format!("{expr} is not a valid function call"))
    };

    if ! unsafe {
        pgrx::is_a(func.as_ptr(),pg_sys::NodeTag::T_FuncCall)
    } {
        return Err(format!("{expr} is not a function"));
    }

    if ! guc::ANON_RESTRICT_TO_TRUSTED_SCHEMAS.get() { return Ok(()); }


    // Create a checkcontext and cast it as a generic context
    let checkcontext_in = CheckContext::new(policy);
    let context_ptr = std::ptr::addr_of!(checkcontext_in)
                      as *mut std::ffi::c_void;

    // Walk through the parse tree and check that the function itself and
    // all other functions used as parameters belong to a trusted schema.
    // The goal is to block privilege escalation attacks using something like:
    //
    // `MASKED WITH FUNCTION pg_catalog.upper(public.elevate())`
    //
    if is_untrusted(func.as_ptr(), context_ptr ) {
        // re-cast the generic context into a checkcontext
        // and return the error upstream
        let checkcontext_out_ptr = context_ptr as *mut CheckContext;
        let checkcontext_out = unsafe {
            checkcontext_out_ptr
                .as_mut()
                .expect("check_function should return a context")
            as &mut CheckContext
        };

        let error_code = <Option<InputError> as Clone>::clone(&checkcontext_out.error_code)
                         .unwrap_or(ERROR_UNKNOWN);

        match error_code {
            ERROR_SCHEMA_NOT_TRUSTED => return Err(format!("{expr} does not belong in a TRUSTED schema")),
            ERROR_FUNCTION_UNTRUSTED => return Err(format!("{expr} is UNTRUSTED")),
            ERROR_FUNCTION_UNQUALIFIED => return Err(format!("{expr} is not qualified")),
            _ => return Err("Unknown error".to_string()),
        }
    }
    Ok(())

}

/// Validate a tablesample expression
///
pub fn check_tablesample( expr: &str ) -> Result<(),String> {

    if expr.is_empty() {
        return Err("Expression is empty".to_string());
    }

    let query_string = format!("SELECT 1 FROM foo {expr}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();

    let raw_parsetree_list = PgTryBuilder::new(||
        Some(unsafe {
            compat::raw_parser(
                query_c_string.as_c_str().as_ptr()
                as *const c_char
            )
        }))
        .catch_others(|_| None)
        .execute();

    // Only one statement in the parsetree is allowed
    if raw_parsetree_list.is_none()
    || raw_parsetree_list.unwrap().is_null()
    || unsafe { raw_parsetree_list.unwrap().as_ref().unwrap().length > 1 } {
        return Err(format!("{expr} is not a valid expression"));
    }

    Ok(())
}

/// check that an expression is a valid masking value
///
pub fn check_value( expr: &str) -> Result<(),String> {
    let val = parse_expression(expr)?;
    if unsafe {
        ! val.is_null()
        && ( pgrx::is_a(val.as_ptr(),pg_sys::NodeTag::T_ColumnRef)
             || pgrx::is_a(val.as_ptr(),pg_sys::NodeTag::T_A_Const)
           )
    } { return Ok(()); }
    Err(format!("{expr} is not a valid expression for a masking value"))
}


/// walk through a parsetree and check that all functions belong in a trusted
/// schema
///
/// the function should not return true without defining an AnonError in
/// the context
///
#[pg_guard]
extern "C" fn is_untrusted(
    node: *mut pg_sys::Node,
    context: *mut ::core::ffi::c_void
) -> bool {

    if node.is_null() { return false ; }

    // Fetch and cast the context
    //let mut checkcontext_ptr = context as *mut CheckContext;
    //let mut checkcontext : &mut CheckContext = unsafe {
    //    checkcontext_ptr.as_ref()
    //                    .expect("Pointer to the Check Context should be valid")
    //};
    let checkcontext_ptr = context as *mut CheckContext;
    let checkcontext = unsafe { &mut *checkcontext_ptr };

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
        if funcname.length != 2 {
            checkcontext.error_code = Some(ERROR_FUNCTION_UNQUALIFIED);
            return true;
        }

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

        let name_val = unsafe {
            PgBox::from_pg(
                pg_sys::pgrx_list_nth(funcname.as_ptr(), 1)
                as *mut compat::SchemaValue
            )
        };
        let name_c_ptr = unsafe{ compat::strVal(*name_val) };

        // Returning true will stop the tree walker right away
        // So the logic is inverted: we stop the search once an unstrusted
        // function is found.
        if let Err(error) = is_trusted_function( namespaceId,
                                                 name_c_ptr,
                                                 checkcontext.policy)
        {
            checkcontext.error_code = Some(error);
            return true;
        }
    }

    unsafe {
        pg_sys::raw_expression_tree_walker( node,
                                            Some(is_untrusted),
                                            context)
    }
}

/// Check that a function is trusted
///
/// A function may have multiple definitions, e.g. foo(INT) and foo(TEXT)
///
/// A function is considered as "trusted for anon" if those 2 conditions are met
///
/// - none of its definition is labeled as `UNTRUSTED`
/// - one its definitions is labeled as `TRUSTED` or it belongs to a `TRUSTED` schema
///
fn is_trusted_function(
    namespace_id: pg_sys::Oid,
    func_name: *const c_char,
    policy: &str
) -> Result<(), InputError>
{
    let mut trusted: Option<bool> = None;

    // Read the Postgres cache to get all the definitions of the function
    // see example below
    // https://github.com/postgres/postgres/blob/23c5a0e7d43bc925c6001538f04a458933a11fc1/src/backend/catalog/namespace.c#L1210
    //
    let catlist= unsafe {
        PgBox::from_pg(pg_sys::SearchSysCacheList(
            pg_sys::SysCacheIdentifier::PROCNAMEARGSNSP.try_into().unwrap(),
            1,
            pg_sys::Datum::from(func_name),
            pg_sys::Datum::from(0),
            pg_sys::Datum::from(0)
        ))
    };

    // transform the members array into a proper rust slice
    let members = unsafe {
        catlist.members.as_slice(catlist.n_members as usize)
    };

    // Each member is a definition of the function
    for def in members {
        // if an unstrusted definition was found previously,
        // then there's no need to check the others
        if ! trusted.unwrap_or(true) { continue };

        // Fetch the tuple from the pg_proc table
        let mut catctup = unsafe { **def as pg_sys::CatCTup };
        let proctup = &mut catctup.tuple as *mut pg_sys::HeapTupleData;
        // procform is a pg_sys::FormData_pg_pro object
        let procform : pgrx::PgBox<pg_sys::FormData_pg_proc> = unsafe {
            PgBox::from_pg(pg_sys::heap_tuple_get_struct(proctup))
        };

        // Skip functions from others namespaces
        if procform.pronamespace != namespace_id { continue } ;

        // Check that the OID is fine
        if ! macros::OidIsValid(procform.oid) {
            error::internal("Function OID is invalid").ereport();
        };

        // Get the security label for this definition
        if let Some(seclabel) = masking::rule(
            pg_sys::ProcedureRelationId,
            procform.oid,
            0,
            policy
        ) {
            // Found no label, skip to the next definition
            if seclabel.is_null() { continue }

            // Read the security label and check its content
            let seclabel_cstr = unsafe { CStr::from_ptr(seclabel.as_ptr()) };
            if re::is_match_trusted(seclabel_cstr) { trusted = Some(true); }
            if re::is_match_untrusted(seclabel_cstr) {
                trusted = Some(false);
            }
        }
    }

    // Release the cache
    unsafe { pg_sys::ReleaseCatCacheList(catlist.as_ptr()); }

    if trusted.is_some() {
        if trusted.unwrap() { return Ok(()) }
        return Err(ERROR_FUNCTION_UNTRUSTED);
    }

    // At this point, if we still don't know whether the function is trusted or
    // not, the last chance is to check if the schema itself is TRUSTED
    is_trusted_namespace(namespace_id,policy)
}

/// Check that a schema is trusted
///
fn is_trusted_namespace(namespace_id: pg_sys::Oid, policy: &str)
-> Result<(), InputError>
{
    if ! macros::OidIsValid(namespace_id) {
        error::internal("Schema OID is invalid").ereport();
    };

    if let Some(seclabel) = masking::rule(
        pg_sys::NamespaceRelationId,
        namespace_id,
        0,
        policy
    ) {
        if seclabel.is_null() {
            return Err(ERROR_SCHEMA_NOT_TRUSTED);
        }
        let seclabel_cstr = unsafe { CStr::from_ptr(seclabel.as_ptr()) };
        if re::is_match_trusted(seclabel_cstr) { return Ok(()); }
    }

    Err(ERROR_SCHEMA_NOT_TRUSTED)
}

/// Parse a given expression and return its raw statement
///
fn parse_expression(expr: &str) -> Result<PgBox<pg_sys::Node>,String>
{
    if expr.is_empty() {
        return Err("Expression is empty".to_string());
    }

    let query_string = format!("SELECT {expr}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let raw_parsetree_list = PgTryBuilder::new(||
        Some(unsafe {
            compat::raw_parser(
                query_c_string.as_c_str().as_ptr()
                as *const c_char
            )
        }))
        .catch_others(|_| None)
        .execute();

    // Only one statement in the parsetree is allowed
    if raw_parsetree_list.is_none()
    || raw_parsetree_list.unwrap().is_null()
    || unsafe { raw_parsetree_list.unwrap().as_ref().unwrap().length > 1 } {
        return Err(format!("{expr} is not a valid expression"));
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
        return Err(format!("{expr} is not a valid expression"));
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
    use crate::fixture;
    use crate::input::*;

    #[pg_test]
    fn test_check_function_ok(){
        let _outfit = fixture::create_masking_functions();
        assert!(check_function("anon.lower('A')","anon").is_ok());
        assert!(check_function("anon.lower(anon.upper('a'))","anon").is_ok());
        assert!(check_function("outfit.mask(0)","anon").is_ok());
    }

    #[pg_test]
    fn test_check_function_err(){
        let _outfit = fixture::create_masking_functions();
        assert!(check_function("foo()","anon").is_err());
        assert!(check_function("pg_catalog.does_not_exist()","anon").is_err());
        assert!(check_function("pg_catalog.pg_ls_dir('/)","anon").is_err());
        assert!(check_function("anon.lower(pg_catalog.pg_ls_dir())","anon").is_err());
        assert!(check_function("outfit.belt()","anon").is_err());
        assert!(check_function("","anon").is_err());
        assert!(check_function("foo(), bar()","anon").is_err());
        assert!(check_function("Robert'); DROP TABLE Students;--","anon").is_err());
    }

    #[pg_test]
    fn test_check_function_unqualified(){
        assert!(check_function("foo()","anon").is_err());
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
    fn test_is_trusted_function(){
        let outfit = fixture::create_masking_functions();
        let mask_cstr = CString::new("mask").unwrap();
        let mask = mask_cstr.as_ptr() as *const c_char;
        let belt_cstr = CString::new("belt").unwrap();
        let belt = belt_cstr.as_ptr() as *const c_char;
        let cape_cstr = CString::new("cape").unwrap();
        let cape = cape_cstr.as_ptr() as *const c_char;

        assert!(is_trusted_function(outfit,mask,"anon").is_ok());
        assert!(is_trusted_function(outfit,belt,"anon").is_err());
        assert!(is_trusted_function(outfit,cape,"anon").is_err());

        // Same tests but now the outfit schema is trusted
        fixture::trust_masking_functions_schema();
        assert!(is_trusted_function(outfit,mask,"anon").is_ok());
        assert!(is_trusted_function(outfit,belt,"anon").is_err());
        assert!(is_trusted_function(outfit,cape,"anon").is_ok());
    }

    #[pg_test]
    fn test_is_trusted_namespace(){
        let gotham = fixture::create_trusted_schema();
        let arkham = fixture::create_untrusted_schema();
        assert!(is_trusted_namespace(gotham,"anon").is_ok());
        assert!(is_trusted_namespace(arkham,"anon").is_err());
    }

    #[pg_test(error = "Anon: Schema OID is invalid")]
    fn test_is_trusted_namespace_invalid_schema(){
        assert!(is_trusted_namespace(0.into(),"anon").is_err());
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
