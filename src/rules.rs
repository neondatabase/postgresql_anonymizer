///
/// # Rules module
///
/// a set of utility functions to check and manage masking rules
///
use crate::error;
use crate::macros;
use crate::masking;
use crate::re;
use pgrx::*;

/// Check that a function is restricted in a given policy
pub fn is_restricted_function(func_id: pg_sys::Oid, policy: &str) -> bool {
    // Check that the OID is fine
    if !macros::OidIsValid(func_id) {
        error::internal("Function OID is invalid").ereport();
    };

    // Get the security label for this definition
    if let Ok(seclabel) = masking::rule_on_function(func_id, policy) {
        return !seclabel.is_empty() && re::is_match_restricted(seclabel);
    }
    false
}

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::label_providers;
    use crate::rules::*;

    static ANON: &str = label_providers::ANON_DEFAULT_MASKING_POLICY;

    #[pg_test]
    fn test_is_restricted_function() {
        let pseudo_id = fixture::create_restricted_function();
        assert!(is_restricted_function(pseudo_id, ANON));

        let lower = Spi::get_one::<pg_sys::Oid>("SELECT 'lower(TEXT)'::REGPROCEDURE::OID;")
            .unwrap()
            .expect("should be an OID");
        assert!(!is_restricted_function(lower, ANON));
    }

    #[pg_test(error = "Anon: Function OID is invalid")]
    fn test_is_restricted_function_invalid() {
        assert!(is_restricted_function(0.into(), ANON));
    }
}
