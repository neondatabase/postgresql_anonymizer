#[allow(unused_imports)]
use pgrx::prelude::*;
use pgrx::PgSqlErrorCode::*;
use std::ffi::CStr;

#[derive(Clone)]
pub struct AnonError {
    error_code: pgrx::PgSqlErrorCode,
    message: String,
    detail: Option<String>,
}

impl AnonError {

    fn new(e: pgrx::PgSqlErrorCode, m: String, d: Option<String>)
    -> AnonError {
        AnonError{ error_code: e, message: m, detail: d }
    }

    pub fn ereport(&self) {
        if self.detail.is_none() {
            pgrx::ereport!(
                ERROR,
                self.error_code,
                format!("Anon: {}", self.message)
            );
        } else {
            let d = <Option<String> as Clone>::clone(&self.detail)
                    .unwrap_or(String::new());
            pgrx::ereport!(
                ERROR,
                self.error_code,
                format!("Anon: {}", self.message),
                format!("{d}")
            );
        }
    }
}

// Postgres error codes
// https://www.postgresql.org/docs/current/errcodes-appendix.html

pub fn feature_not_supported(feature: &str) -> AnonError {
    AnonError::new(
        ERRCODE_FEATURE_NOT_SUPPORTED,
        format!("{feature} is not supported"),
        None
    )
}

pub fn function_call_is_empty() -> AnonError {
    AnonError::new(
        ERRCODE_NO_DATA,
        "function call is empty".to_string(),
        None
    )
}

pub fn function_is_not_valid(function_call: &str) -> AnonError {
    AnonError::new(
        ERRCODE_INVALID_NAME,
        format!("'{function_call}' is not a valid function call"),
        None
    )
}

pub fn insufficient_privilege(reason: String) -> AnonError {
    AnonError::new(
        ERRCODE_INSUFFICIENT_PRIVILEGE,
        reason,
        None
    )
}

pub fn invalid_label_for(an_object: &str, label: &CStr, hint: Option<String>)
-> AnonError {
    let label_str = label.to_str().expect("label should be a correct CStr");
    AnonError::new(
        ERRCODE_SYNTAX_ERROR,
        format!("`{label_str}` is not a valid label for {an_object}"),
        hint
    )
}

pub fn internal(message: &str) -> AnonError {
    AnonError::new(
        ERRCODE_INTERNAL_ERROR,
        message.to_string(),
        Some("This is probably a bug, please report it.".to_string())
    )
}

pub fn not_implemented_yet() -> AnonError {
    AnonError::new(
        ERRCODE_FEATURE_NOT_SUPPORTED,
        "not implemented yet".to_string(),
        None
    )
}

pub fn policy_not_defined() -> AnonError {
    AnonError::new(
        ERRCODE_NO_DATA,
        "the masking policy is not defined".to_string(),
        None
    )
}

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::error::*;

    #[pg_test(error = "Anon: This is a test of the internal error")]
    fn test_internal(){
        let i = internal("This is a test of the internal error");
        i.ereport();
    }
}
