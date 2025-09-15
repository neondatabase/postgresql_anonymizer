///
/// # Sampling
///
use crate::masking;
use crate::re;
use pgrx::prelude::*;

pub fn get_ratio(relid: pg_sys::Oid, policy: &str) -> Option<&str> {
    get_table_ratio(relid, policy).or(get_current_database_ratio(policy))
}

fn get_current_database_ratio(policy: &str) -> Option<&str> {
    let current_db_id = unsafe { pg_sys::MyDatabaseId };
    let seclabel = masking::rule_on_database(current_db_id, policy).ok();
    re::capture_tablesample(seclabel?)
}

pub fn get_table_ratio(relid: pg_sys::Oid, policy: &str) -> Option<&str> {
    let seclabel = masking::rule_on_table(relid, policy).ok();
    re::capture_tablesample(seclabel?)
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::label_providers::ANON_DEFAULT_MASKING_POLICY;
    use crate::masking;
    use crate::sampling::*;
    use std::ffi::CStr;

    #[pg_test]
    fn test_get_current_database_ratio() {
        let db_name_ptr = unsafe { pg_sys::get_database_name(pg_sys::MyDatabaseId) };
        let db_name_cstr = unsafe { CStr::from_ptr(db_name_ptr) };
        assert!(get_current_database_ratio(ANON_DEFAULT_MASKING_POLICY).is_none());
        fixture::declare_sampling_for_database(db_name_cstr.to_str().unwrap().to_string());
        assert!(get_current_database_ratio(ANON_DEFAULT_MASKING_POLICY).is_some());
    }

    #[pg_test]
    fn test_get_current_database_ratio_none() {
        assert!(get_current_database_ratio(ANON_DEFAULT_MASKING_POLICY).is_none());
    }

    #[pg_test]
    fn test_get_table_ratio() {
        let relid = fixture::create_table_person();
        assert_eq!(
            Some("BERNOULLI(10)"),
            get_table_ratio(relid, ANON_DEFAULT_MASKING_POLICY)
        );
    }

    #[pg_test]
    fn test_get_table_ratio_no_policy() {
        let relid = fixture::create_table_person();
        assert!(get_table_ratio(relid, "does_not_exist").is_none());
        assert!(get_table_ratio(relid, "").is_none());
    }

    #[pg_test]
    fn test_get_table_ratio_invalid_oid() {
        let invalid = pg_sys::InvalidOid;
        assert!(get_table_ratio(invalid, ANON_DEFAULT_MASKING_POLICY).is_none());
    }

    #[pg_test]
    fn test_get_table_ratio_none() {
        let relid = fixture::create_table_location();
        assert!(get_table_ratio(relid, ANON_DEFAULT_MASKING_POLICY).is_none());
    }
}
