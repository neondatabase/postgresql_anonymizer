///
/// # Custom compatibility types and functions
///
/// Each major version of Postgres may introduce internal API changes.
///
/// We're declaring here a set of replacements to avoid conditional macro
/// codeblocks in the main extension codebase.
///

use pgrx::prelude::*;
use std::os::raw::c_char;

///
/// rawparser function
///

#[cfg(any(feature = "pg12", feature = "pg13"))]
pub unsafe fn raw_parser(query: *const c_char) -> *mut pg_sys::List {
    pg_sys::raw_parser(query)
}

#[cfg(any(feature = "pg14", feature = "pg15", feature = "pg16"))]
pub unsafe fn raw_parser(query: *const c_char) -> *mut pg_sys::List {
    pg_sys::raw_parser(query,pg_sys::RawParseMode::RAW_PARSE_DEFAULT)
}

///
/// SchemaValue type
///

#[cfg(any(feature = "pg15", feature = "pg16"))]
pub use pgrx::pg_sys::String as SchemaValue;

#[cfg(any(feature = "pg11", feature = "pg12", feature = "pg13", feature = "pg14"))]
pub use pgrx::pg_sys::Value as SchemaValue;

///
/// strVal macro
///

#[allow(non_snake_case)]
#[cfg(any(feature = "pg15", feature = "pg16"))]
pub unsafe fn strVal(v: SchemaValue) -> *const c_char { v.sval }

#[allow(non_snake_case)]
#[cfg(any(feature = "pg11", feature = "pg12", feature = "pg13", feature = "pg14"))]
pub unsafe fn strVal(v: SchemaValue) -> *const c_char { v.val.str_ }
