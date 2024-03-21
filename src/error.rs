use pgrx::ereport;
use pgrx::PgSqlErrorCode::*;


pub fn invalid_label_database(element: &str, hint: &str) {
    ereport!(
        ERROR,
        ERRCODE_SYNTAX_ERROR,
        format!("'{}' is not a valid label for a database", element),
        hint
    );
}
