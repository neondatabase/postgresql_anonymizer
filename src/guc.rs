//----------------------------------------------------------------------------
// GUC Variables
//----------------------------------------------------------------------------

use pgrx::*;
use std::ffi::{c_void, CStr, CString};

pub static ANON_DUMMY_LOCALE: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c"en_US"));

pub static ANON_K_ANONYMITY_PROVIDER: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c"k_anonymity"));

pub static ANON_MASKING_POLICIES: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c""));

pub static ANON_PRIVACY_BY_DEFAULT: GucSetting<bool> = GucSetting::<bool>::new(false);

pub static ANON_RESTRICT_TO_TRUSTED_SCHEMAS: GucSetting<bool> = GucSetting::<bool>::new(true);

pub static ANON_STRICT_MODE: GucSetting<bool> = GucSetting::<bool>::new(true);

pub static ANON_TRANSPARENT_DYNAMIC_MASKING: GucSetting<bool> = GucSetting::<bool>::new(false);

pub static ANON_STATIC_MASKING: GucSetting<bool> = GucSetting::<bool>::new(true);

// The GUC vars below are not used in the Rust code
// but they are used in the plpgsql code

static ANON_ALGORITHM: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c"sha256"));

static ANON_SALT: GucSetting<Option<CString>> = GucSetting::<Option<CString>>::new(Some(c""));

static ANON_SOURCE_SCHEMA: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c"public"));

static ANON_MASK_SCHEMA: GucSetting<Option<CString>> =
    GucSetting::<Option<CString>>::new(Some(c"mask"));

unsafe extern "C-unwind" fn check_bool_guc_hook(
    _newval: *mut bool,
    _extra: *mut *mut c_void,
    source: u32,
) -> bool {
    unsafe {
        // The sources that we allow are:
        // 1. PGC_S_DEFAULT (0) -> for default boot up source, likely new session or server.
        // 2. PGC_S_DATABASE (6) -> a GUC set for a particular database
        // 3. PGC_S_USER (7) -> a GUC set for a particular role
        // 4. PGC_S_DATABASE_USER (8) -> a GUC set for a particular role in a particular database
        // This check only allows sources that load a variable, not ones that try to alter it.
        // Sources that try to alter it are:
        // 1. PGC_S_FILE (3) -> ALTER SYSTEM
        // 2. PGC_S_TEST (12) -> ALTER ROLE/DATABASE
        // 3. PGC_S_SESSION (13) -> SET ...
        // TODO (thesuhas): Does PGC_S_GLOBAL need to be added to whitelisted sources?
        pg_sys::info!("Source: {}", source);
        if source == 0 || source == 6 || source == 7 || source == 8 {
            return true;
        }
        let oid = pg_sys::GetUserId();
        let user_name = CStr::from_ptr(pg_sys::GetUserNameFromId(oid, true));
        let user_str = user_name.to_str().unwrap();
        pg_sys::info!("user: {} trying to change boolean guc", user_str);
        if pg_sys::superuser() || user_str == "neon_superuser" || user_str == "neondb_owner" {
            return true;
        }
        pg_sys::ereport!(
            PgLogLevel::ERROR,
            PgSqlErrorCode::ERRCODE_INSUFFICIENT_PRIVILEGE,
            "You are not authorized to change this GUC"
        );
        false
    }
}

unsafe extern "C-unwind" fn check_string_guc_hook(
    _newval: *mut *mut libc::c_char,
    _extra: *mut *mut c_void,
    source: u32,
) -> bool {
    unsafe {
        // The sources that we allow are:
        // 1. PGC_S_DEFAULT (0) -> for default boot up source, likely new session or server.
        // 2. PGC_S_DATABASE (6) -> a GUC set for a particular database
        // 3. PGC_S_USER (7) -> a GUC set for a particular role
        // 4. PGC_S_DATABASE_USER (8) -> a GUC set for a particular role in a particular database
        // This check only allows sources that load a variable, not ones that try to alter it.
        // Sources that try to alter it are:
        // 1. PGC_S_FILE (3) -> ALTER SYSTEM
        // 2. PGC_S_TEST (12) -> ALTER ROLE/DATABASE
        // 3. PGC_S_SESSION (13) -> SET ...
        pg_sys::info!("Source: {}", source);
        if source == 0 || source == 6 || source == 7 || source == 8 {
            return true;
        }
        let oid = pg_sys::GetUserId();
        let user_name = CStr::from_ptr(pg_sys::GetUserNameFromId(oid, true));
        let user_str = user_name.to_str().unwrap();
        pg_sys::info!("user: {} trying to change string guc", user_str);
        if pg_sys::superuser() || user_str == "neon_superuser" || user_str == "neondb_owner" {
            return true;
        }
        pg_sys::ereport!(
            PgLogLevel::ERROR,
            PgSqlErrorCode::ERRCODE_INSUFFICIENT_PRIVILEGE,
            "You are not authorized to change this GUC"
        );
        false
    }
}

// Register the GUC parameters for the extension
//
pub fn register_gucs() {
    unsafe {
        GucRegistry::define_string_guc_with_hooks(
            c"anon.dummy_locale",
            c"The default locale for the dummy data functions",
            c"",
            &ANON_DUMMY_LOCALE,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY,
            Some(check_string_guc_hook),
            None,
            None,
        );

        GucRegistry::define_string_guc_with_hooks(
            c"anon.k_anonymity_provider",
            c"The security label provider used for k-anonymity",
            c"",
            &ANON_K_ANONYMITY_PROVIDER,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY,
            Some(check_string_guc_hook),
            None,
            None,
        );

        //
        // As of PGRX 0.12, GUC_LIST_INPUT is not supported which means this
        // parameter can't be properly handled by `SHOW anon.masking_policies` or
        // in the pg_settings catalog. And SplitGUCList has a really weird
        // behaviour with `anon.masking_policies` ¯\_(ツ)_/¯
        //
        // https://github.com/pgcentralfoundation/pgrx/commit/d096efe6fb2d86e87d117b520b9ccd2f90b2e0d1
        //
        GucRegistry::define_string_guc_with_hooks(
            c"anon.masking_policies",
            c"Define additional masking policies (the 'anon' policy is already defined)",
            c"",
            &ANON_MASKING_POLICIES,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY, /* | GucFlags::LIST_INPUT */
            Some(check_string_guc_hook),
            None,
            None,
        );

        GucRegistry::define_bool_guc_with_hooks(
            c"anon.privacy_by_default",
            c"Mask all columns with NULL (or the default value for NOT NULL columns)",
            c"",
            &ANON_PRIVACY_BY_DEFAULT,
            GucContext::Userset,
            GucFlags::default(),
            Some(check_bool_guc_hook),
            None,
            None,
        );
        GucRegistry::define_bool_guc_with_hooks(
            c"anon.transparent_dynamic_masking",
            c"New masking engine (EXPERIMENTAL)",
            c"",
            &ANON_TRANSPARENT_DYNAMIC_MASKING,
            GucContext::Userset,
            GucFlags::default(),
            Some(check_bool_guc_hook),
            None,
            None,
        );

        GucRegistry::define_bool_guc_with_hooks(
            c"anon.restrict_to_trusted_schemas",
            c"Masking filters must be in a trusted schema",
            c"Activate this option to prevent non-superuser from using their own masking filters",
            &ANON_RESTRICT_TO_TRUSTED_SCHEMAS,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY,
            Some(check_bool_guc_hook),
            None,
            None,
        );

        GucRegistry::define_bool_guc_with_hooks(
            c"anon.strict_mode",
            c"A masking rule cannot change a column data type, unless you disable this",
            c"Disabling the mode is not recommended",
            &ANON_STRICT_MODE,
            GucContext::Userset,
            GucFlags::default(),
            Some(check_bool_guc_hook),
            None,
            None,
        );

        // The GUC vars below are not used in the Rust code
        // but they are used in the plpgsql code

        GucRegistry::define_string_guc_with_hooks(
            c"anon.algorithm",
            c"The hash method used for pseudonymizing functions",
            c"",
            &ANON_ALGORITHM,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY,
            Some(check_string_guc_hook),
            None,
            None,
        );

        GucRegistry::define_string_guc_with_hooks(
            c"anon.maskschema",
            c"The schema where the dynamic masking views are stored",
            c"",
            &ANON_MASK_SCHEMA,
            GucContext::Userset,
            GucFlags::default(),
            Some(check_string_guc_hook),
            None,
            None,
        );

        GucRegistry::define_string_guc_with_hooks(
            c"anon.salt",
            c"The salt value used for the pseudonymizing functions",
            c"",
            &ANON_SALT,
            GucContext::Suset,
            GucFlags::SUPERUSER_ONLY,
            Some(check_string_guc_hook),
            None,
            None,
        );

        GucRegistry::define_string_guc_with_hooks(
            c"anon.sourceschema",
            c"The schema where the table are masked by the dynamic masking engine",
            c"",
            &ANON_SOURCE_SCHEMA,
            GucContext::Userset,
            GucFlags::default(),
            Some(check_string_guc_hook),
            None,
            None,
        );
    }
}
