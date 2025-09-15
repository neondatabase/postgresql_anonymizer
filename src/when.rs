///
/// # Selective Masking
///
use crate::masking;
use crate::re;
use pgrx::prelude::*;

/// Extract the `MASKED WHEN` condition of a table
///
pub fn get_table_when(relid: pg_sys::Oid, policy: &str) -> Option<&str> {
    let seclabel = masking::rule_on_table(relid, policy).ok();
    re::capture_when(seclabel?)
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
    use crate::when::*;

    #[pg_test]
    fn test_get_table_when() {
        let relid = fixture::create_table_account();
        assert_eq!(
            Some("NOT is_admin"),
            get_table_when(relid, ANON_DEFAULT_MASKING_POLICY)
        );
    }

    #[pg_test]
    fn test_get_table_when_no_policy() {
        let relid = fixture::create_table_account();
        assert!(get_table_when(relid, "does_not_exist").is_none());
        assert!(get_table_when(relid, "").is_none());
    }

    #[pg_test]
    fn test_get_table_when_invalid_oid() {
        let invalid = pg_sys::InvalidOid;
        assert!(get_table_when(invalid, ANON_DEFAULT_MASKING_POLICY).is_none());
    }

    #[pg_test]
    fn test_get_table_when_none() {
        let relid = fixture::create_table_location();
        assert!(get_table_when(relid, ANON_DEFAULT_MASKING_POLICY).is_none());
    }
}
