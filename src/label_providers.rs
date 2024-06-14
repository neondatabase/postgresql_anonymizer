///
/// # Security Label Providers
///
/// The *_relabel functions are called every time a security label is declared
///

use crate::error;
use crate::guc;
use crate::input;
use crate::masking;
use crate::re;
use pgrx::prelude::*;
use pgrx::PgSqlErrorCode::*;
use std::ffi::CStr;

pub fn register_label_providers() {

    // Register the security label provider for k-anonymity
    unsafe {
        pg_sys::register_label_provider(
            guc::ANON_K_ANONYMITY_PROVIDER
                .get()
                .unwrap()
                .to_bytes_with_nul()
                .as_ptr() as *const i8,
            Some(k_anonymity_object_relabel),
        )
    };

    // Register the masking policies
    for policy in masking::list_masking_policies().iter() {
        debug1!("Anon: registering masking policy '{}'", policy.unwrap());
        // transform the str back into a C Pointer
        let c_ptr_policy = policy.unwrap().as_ptr();
        unsafe {
            pg_sys::register_label_provider(
                c_ptr_policy as *const i8,
                Some(masking_policy_object_relabel),
            )
        }
    }
}

/// Checking the syntax of a k-anonymity rules
///
#[pg_guard]
unsafe extern "C" fn k_anonymity_object_relabel(
    object_ptr: *const pg_sys::ObjectAddress,
    seclabel_ptr: *const i8,
) {
    debug1!("Anon: Checking the K-Anonymity Security Label");

    /* SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS NULL */
    if seclabel_ptr.is_null() {
        return
    }

    // Transform the object C pointer into a smart pointer
    let object = unsafe {
        PgBox::<pg_sys::ObjectAddress>::from_pg(
            object_ptr as *mut pg_sys::ObjectAddress
        )
    };

    /*
     * SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS 'INDIRECT IDENTIFIER';
     * SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS 'QUASI IDENTIFIER';
     */
    if object.classId == pg_sys::RelationRelationId {
        let seclabel_cstr = unsafe { CStr::from_ptr(seclabel_ptr) };
        let seclabel_str  = seclabel_cstr.to_str().unwrap();
        if re::is_match_indirect_identifier(seclabel_cstr) {
            return
        }
        ereport!(
            ERROR,
            ERRCODE_INVALID_NAME,
            format!("'{}' is not a valid label for a column", seclabel_str)
        );
    }
    ereport!(
        ERROR,
        ERRCODE_FEATURE_NOT_SUPPORTED,
        "The k_anonymity provider does not support labels on this object"
    );
}


/// Checking the syntax of a masking rule
///
/// This function is a callback called whenever a SECURITY LABEL is declared on
/// a registered masking policy
///
#[pg_guard]
unsafe extern "C" fn masking_policy_object_relabel(
    object_ptr: *const pg_sys::ObjectAddress,
    seclabel_ptr: *const i8,
) {
    use crate::re;

    /* SECURITY LABEL FOR anon ON COLUMN foo.bar IS NULL */
    if seclabel_ptr.is_null() {
        return
    }

    // convert the object C pointer into a smart pointer
    let object = unsafe {
        PgBox::<pg_sys::ObjectAddress>::from_pg(
            object_ptr as *mut pg_sys::ObjectAddress
        )
    };

    // convert the C string pointer into a Rust string
    let seclabel_cstr = unsafe { CStr::from_ptr(seclabel_ptr) };
    let string_seclabel = seclabel_cstr.to_str().unwrap().to_string();

    match object.classId {
        /* SECURITY LABEL FOR anon ON DATABASE d IS 'TABLESAMPLE SYSTEM(10)' */
        pg_sys::DatabaseRelationId => {
            if re::is_match_tablesample(seclabel_cstr) {
                let check_tbs = input::check_tablesample(&string_seclabel);
                if check_tbs.is_ok() { return; }
                error::invalid_label_database(&string_seclabel,
                                              check_tbs.unwrap_err());
            }
            error::invalid_label_database(&string_seclabel,"Syntax error");
        }
        /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
        pg_sys::RelationRelationId => {
            /*
             * RelationRelationId will match either a table or a column !
             * If the object subId is 0, it's a table
             */

            /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
            if object.objectSubId == 0 {
                if re::is_match_tablesample(seclabel_cstr) {
                    let check_tbs = input::check_tablesample(&string_seclabel);
                    if check_tbs.is_ok() { return; }
                    ereport!(
                        ERROR,
                        ERRCODE_INVALID_NAME,
                        format!("'{}' is not a valid label for a table", string_seclabel),
                        format!("{}",check_tbs.unwrap_err())
                    );
                }
                ereport!(
                    ERROR,
                    ERRCODE_SYNTAX_ERROR,
                    format!("'{}' is not a valid label for a table", string_seclabel),
                    "Syntax error"
                );
            } else {
                /* Check that the column does not belong to a view */
                if pg_sys::get_rel_relkind(object.objectId) == 'v' as i8 {
                    ereport!(
                        ERROR,
                        ERRCODE_FEATURE_NOT_SUPPORTED,
                        "Masking a view is not supported"
                    );
                }
                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
                if let Some(val) = re::capture_value(seclabel_cstr) {
                    let check_val = input::check_value(val);
                    if check_val.is_ok() { return; }
                    ereport!(
                        ERROR,
                        ERRCODE_INVALID_NAME,
                        format!("'{}' is not a valid label for a column", string_seclabel),
                        format!("{}",check_val.unwrap_err())
                    );
                }

                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH FUNCTION $x$' */
                if let Some(func) = re::capture_function(seclabel_cstr) {
                    let check_func = input::check_function(func);
                    if check_func.is_ok() { return ; }
                    ereport!(
                        ERROR,
                        ERRCODE_INVALID_NAME,
                        format!("'{}' is not a valid label for a column",string_seclabel),
                        format!("{}",check_func.unwrap_err())
                    );
                }

                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'NOT MASKED */
                if re::is_match_not_masked(seclabel_cstr) {
                    return;
                }
                ereport!(
                    ERROR,
                    ERRCODE_INVALID_NAME,
                    format!("'{}' is not a valid label for a column", string_seclabel),
                    "syntax error"
                );
            }
        }

        /* SECURITY LABEL FOR anon ON ROLE batman IS 'MASKED' */
        pg_sys::AuthIdRelationId => {
            if re::is_match_masked(seclabel_cstr) {
                return
            }
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{}' is not a valid label for a role", string_seclabel)
            );
        }
        /* SECURITY LABEL FOR anon ON SCHEMA public IS 'TRUSTED' */
        pg_sys::NamespaceRelationId => {
            if !pg_sys::superuser() {
                ereport!(
                    ERROR,
                    ERRCODE_INSUFFICIENT_PRIVILEGE,
                    "only superuser can set an anon label for a schema"
                );
            }
            if re::is_match_trusted(seclabel_cstr) {
                return
            }
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{}' is not a valid label for a schema", string_seclabel)
            );
        }

        /* Everything else is not supported */
        _ => {
            ereport!(
                ERROR,
                ERRCODE_FEATURE_NOT_SUPPORTED,
                "The anon extension does not support labels on this object"
            );
        }
    }
}
