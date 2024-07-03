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
use std::ffi::CStr;

pub fn register_label_providers() {

    // Register the main masking policy
    // the name "anon" is hard-coded, we don't want user to modify it
    unsafe {
        let policy = "anon";
        let c_ptr_policy = policy.as_ptr();
        pg_sys::register_label_provider(
            c_ptr_policy as *const i8,
            Some(masking_policy_object_relabel)
        );
    }

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

    /* SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS NULL */
    if seclabel_ptr.is_null() { return }

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
        let label = unsafe { CStr::from_ptr(seclabel_ptr) };
        if re::is_match_indirect_identifier(label) { return }
        error::invalid_label_for("a column",label,None).ereport();
    }

    /* Everything else is not supported */
    error::feature_not_supported(
        "Placing a k_anonymity label on this object"
    ).ereport();
}


/// Checking the syntax of a masking rule
///
/// This function is a callback called whenever a SECURITY LABEL is declared on
/// a registered masking policy
///
/// The function returns `()` if the label if fine
/// otherwise it throws an error via ereport() to ROLLBACK the transaction
///
#[pg_guard]
unsafe extern "C" fn masking_policy_object_relabel(
    object_ptr: *const pg_sys::ObjectAddress,
    seclabel_ptr: *const i8,
) {

    /* SECURITY LABEL FOR anon ON COLUMN foo.bar IS NULL */
    if seclabel_ptr.is_null() { return }

    // convert the object C pointer into a smart pointer
    let object = unsafe {
        PgBox::<pg_sys::ObjectAddress>::from_pg(
            object_ptr as *mut pg_sys::ObjectAddress
        )
    };

    // Extract the security label
    let label = unsafe { CStr::from_ptr(seclabel_ptr) };

    match object.classId {
        /* SECURITY LABEL FOR anon ON FUNCTION public.foo() IS 'TRUSTED' */
        pg_sys::ProcedureRelationId => { relabel_function(label) }

        /* SECURITY LABEL FOR anon ON DATABASE d IS 'TABLESAMPLE SYSTEM(10)' */
        pg_sys::DatabaseRelationId => { relabel_database(label) }

        /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
        /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
        /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH FUNCTION $x$' */
        /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'NOT MASKED */
        pg_sys::RelationRelationId => {
            /*
             * RelationRelationId will match either a table or a column !
             * If the object subId is 0, it's a table
             */

            if object.objectSubId == 0 {
                /* SECURITY LABEL FOR anon ON TABLE t IS '[...]' */
                relabel_table(label)
            } else {
                /* SECURITY LABEL FOR anon ON COLUMN t.i IS '[...]' */
                relabel_column(label,object.objectId)
            }
        }

        /* SECURITY LABEL FOR anon ON ROLE batman IS 'MASKED' */
        pg_sys::AuthIdRelationId => { relabel_role(label) }

        /* SECURITY LABEL FOR anon ON SCHEMA public IS 'TRUSTED' */
        pg_sys::NamespaceRelationId => { relabel_schema(label) }

        /* Any other label is refused */
        _ => { error::feature_not_supported("Labeling this object").ereport() }
    }
}

fn relabel_column(label: &CStr, object_id: pg_sys::Oid) {
    /* Check that the column does not belong to a view */
    if unsafe { pg_sys::get_rel_relkind(object_id) == 'v' as i8 } {
        error::feature_not_supported("Masking a view").ereport();
    }

    /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
    if let Some(val) = re::capture_value(label) {
        let check_val = input::check_value(val);
        if check_val.is_ok() { return; }
        error::invalid_label_for(
            "a column",label,Some(check_val.unwrap_err())
        ).ereport();
    }

    /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH FUNCTION $x$' */
    if let Some(func) = re::capture_function(label) {
        let check_func = input::check_function(func,"anon");
        if check_func.is_ok() { return ; }
        error::invalid_label_for(
            "a column",label,Some(check_func.unwrap_err())
        ).ereport();
    }

    /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'NOT MASKED */
    if re::is_match_not_masked(label) { return; }

    error::invalid_label_for("a column",label,None).ereport();
}

fn relabel_database(label: &CStr) {
    let mut detail : Option<String> = None;

    if re::is_match_tablesample(label) {
        let check_tbs = input::check_tablesample(label.to_str().unwrap());
        if check_tbs.is_ok() { return }
        detail = Some(check_tbs.unwrap_err());
    }

    error::invalid_label_for("a database", label, detail).ereport();
}

fn relabel_function(label: &CStr) {

    if ! unsafe { pg_sys::superuser() } {
        error::insufficient_privilege(
            "only a superuser can set an anon label for a function".to_string()
        ).ereport();
    }

    if re::is_match_trusted(label) || re::is_match_untrusted(label) {
                return
    }

    error::invalid_label_for("a function",label,None).ereport();
}

fn relabel_role(label: &CStr) {
    if re::is_match_masked(label) { return }
    error::invalid_label_for("a role",label,None).ereport();
}

fn relabel_schema(label: &CStr) {
    if ! unsafe { pg_sys::superuser() } {
        error::insufficient_privilege(
            "only a superuser can set an anon label for a schema".to_string()
        ).ereport();
    }
    if re::is_match_trusted(label) { return }

    error::invalid_label_for("a schema",label,None ).ereport();
}

// relabel_table is **almost** equivalent to relabel_database
fn relabel_table(label: &CStr) {
    let mut detail : Option<String> = None;
    if re::is_match_tablesample(label) {
        let check_tbs = input::check_tablesample(label.to_str().unwrap());
        if check_tbs.is_ok() { return; }
        detail = Some(check_tbs.unwrap_err());
    }
    error::invalid_label_for("a table", label, detail).ereport();
}
