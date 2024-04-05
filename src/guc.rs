//----------------------------------------------------------------------------
// GUC Variables
//----------------------------------------------------------------------------

use pgrx::*;
use std::ffi::CStr;


pub static ANON_DUMMY_LOCALE: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"en_US\0")
    }));

pub static ANON_K_ANONYMITY_PROVIDER: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"k_anonymity\0")
    }));

pub static ANON_MASKING_POLICIES: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"anon\0")
    }));

pub static ANON_PRIVACY_BY_DEFAULT: GucSetting<bool> =
    GucSetting::<bool>::new(false);

pub static ANON_RESTRICT_TO_TRUSTED_SCHEMAS: GucSetting<bool> =
    GucSetting::<bool>::new(true);

pub static ANON_STRICT_MODE: GucSetting<bool> =
    GucSetting::<bool>::new(true);

pub static ANON_TRANSPARENT_DYNAMIC_MASKING: GucSetting<bool> =
    GucSetting::<bool>::new(false);

// The GUC vars below are not used in the Rust code
// but they are used in the plpgsql code

static ANON_ALGORITHM: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"sha256\0")
    }));

static ANON_SALT: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"\0")
    }));

static ANON_SOURCE_SCHEMA: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"public\0")
    }));

static ANON_MASK_SCHEMA: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"mask\0")
    }));

// Register the GUC parameters for the extension
//
pub fn register_gucs() {

    GucRegistry::define_string_guc(
        "anon.dummy_locale",
        "The default locale for the dummy data functions",
        "",
        &ANON_DUMMY_LOCALE,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.k_anonymity_provider",
        "The security label provider used for k-anonymity",
        "",
        &ANON_K_ANONYMITY_PROVIDER,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.masking_policies",
        "Define multiple masking policies (NOT IMPLEMENTED YET)",
        "",
        &ANON_MASKING_POLICIES,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY, /* GUC_LIST_INPUT is not available ? */
    );

    GucRegistry::define_bool_guc(
        "anon.privacy_by_default",
        "Mask all columns with NULL (or the default value for NOT NULL columns)",
        "",
        &ANON_PRIVACY_BY_DEFAULT,
        GucContext::Suset,
        GucFlags::default(),
    );
   GucRegistry::define_bool_guc(
        "anon.transparent_dynamic_masking",
        "New masking engine (EXPERIMENTAL)",
        "",
        &ANON_TRANSPARENT_DYNAMIC_MASKING,
        GucContext::Suset,
        GucFlags::default(),
    );

    GucRegistry::define_bool_guc(
        "anon.restrict_to_trusted_schemas",
        "Masking filters must be in a trusted schema",
        "Activate this option to prevent non-superuser from using their own masking filters",
        &ANON_RESTRICT_TO_TRUSTED_SCHEMAS,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_bool_guc(
        "anon.strict_mode",
        "A masking rule cannot change a column data type, unless you disable this",
        "Disabling the mode is not recommended",
        &ANON_STRICT_MODE,
        GucContext::Suset,
        GucFlags::default(),
    );

    // The GUC vars below are not used in the Rust code
    // but they are used in the plpgsql code

    GucRegistry::define_string_guc(
        "anon.algorithm",
        "The hash method used for pseudonymizing functions",
        "",
        &ANON_ALGORITHM,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.maskschema",
        "The schema where the dynamic masking views are stored",
        "",
        &ANON_MASK_SCHEMA,
        GucContext::Suset,
        GucFlags::default(),
    );

    GucRegistry::define_string_guc(
        "anon.salt",
        "The salt value used for the pseudonymizing functions",
        "",
        &ANON_SALT,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.sourceschema",
        "The schema where the table are masked by the dynamic masking engine",
        "",
        &ANON_SOURCE_SCHEMA,
        GucContext::Suset,
        GucFlags::default(),
    );


}
