///
/// # Postgres C Macros
///
/// PGRX does not include bindings the Postgres C macros
///
/// We're reimplementing a few useful ones
///
use pgrx::pg_sys;
use std::ffi::CStr;

#[allow(non_snake_case)]
pub fn OidIsValid(objectId: pg_sys::Oid) -> bool {
    objectId != pg_sys::InvalidOid
}

#[allow(non_snake_case)]
pub fn NameDataStr(name: pg_sys::NameData) -> &'static str {
    let name_cstr = unsafe { CStr::from_ptr(name.data.as_ptr()) };
    name_cstr.to_str().expect("Name should be a valid")
}
