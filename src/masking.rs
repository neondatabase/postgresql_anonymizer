///
/// # Masking Engine
///

use c_str_macro::c_str;
use crate::guc;
use crate::re;
use pgrx::prelude::*;
use pgrx::PgSqlErrorCode::*;
use std::ffi::CStr;
use std::ffi::CString;
use std::os::raw::c_char;

//----------------------------------------------------------------------------
// Public functions
//----------------------------------------------------------------------------

/// Decorate a value with a CAST function
///
/// Example: the value `1` will be transformed into `CAST(1 AS INT)`
///
/// * value is the value to transform
/// * atttypid is the id of the type for this data
///
pub fn cast_as_regtype(value: String, atttypid: pg_sys::Oid) -> String {
    let type_be = unsafe { CStr::from_ptr(pg_sys::format_type_be(atttypid)) }
        .to_str()
        .unwrap();
    format!("CAST({value} AS {type_be})")
}

/// For a given role, returns the policy in which he/she is masked
/// or the NULL if the role is not masked.
///
/// * roleid is the id of the user we want to mask
///
pub fn get_masking_policy(roleid: pg_sys::Oid) ->  Option<String> {
    // Possible Improvement : allow masking rule inheritance by checking
    // also the roles that the user belongs to
    // This may be done by using `roles_is_member_of()` ?
    for policy in list_masking_policies() {
        if has_mask_in_policy(roleid,policy.unwrap()) {
            return Some(policy.unwrap().to_string());
        }
    }
    // Found nothing, return NULL
    None
}

///
/// Initialize the extension
///
pub fn init_masking_policies() -> bool {
    // For some reasons, this can't be done int PG_init()
    for _policy in list_masking_policies().iter() {
        Spi::run("SECURITY LABEL FOR anon ON SCHEMA anon IS 'TRUSTED'")
            .expect("SPI Failed to set schema anon as trusted");
    }
    true
}

/// Return all the registered masking policies
///
/// NOTE: we can't return a Vec<Option<String>> here because it seems that
/// `register_label_provider(...)` needs a &'static str
///
/// TODO: `SplitGUCList` from varlena.h is not available in PGRX 0.11
///
pub fn list_masking_policies() -> Vec<Option<&'static str>> {

    // transform the GUC (CStr pointer) into a Rust String
    let masking_policies = guc::ANON_MASKING_POLICIES.get()
                          .unwrap().to_str().expect("Should be a string");

                          // remove the white spaces
    //masking_policies.retain(|c| !c.is_whitespace());
    if masking_policies.is_empty() {
        ereport!(
            ERROR,
            ERRCODE_NO_DATA,
            "Anon: the masking policy is not defined"
        );
    }

    return masking_policies.split(',').map(Some).collect();
}

/// Returns the "select clause filters" that will mask the authentic data
/// of a table for a given masking policy
///
pub fn masking_expressions_for_table(
    relid: pg_sys::Oid,
    policy: String
) -> String {

    let lockmode = pg_sys::AccessShareLock as i32;

    // `pg_sys::relation_open()` will raise XX000
    // if the specified oid isn't a valid relation
    let relation = unsafe {
        PgBox::from_pg(pg_sys::relation_open(relid, lockmode))
    };

    // reldesc is a TupleDescData object
    // https://doxygen.postgresql.org/structTupleDescData.html
    let reldesc = unsafe { PgBox::from_pg(relation.rd_att) };
    let natts = reldesc.natts;
    let attrs = unsafe {
        reldesc.attrs.as_slice(natts.try_into().unwrap())
    };

    let mut expressions = Vec::new();
    for a in attrs {
        if a.attisdropped {
            continue;
        }
        let filter_value = value_for_att(&relation, a, policy.clone());
        let attname_quoted = quote_name_data(&a.attname);
        let filter = format!("{filter_value} AS {attname_quoted}");
        expressions.push(filter);
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    expressions.join(", ").to_string()
}

/// Returns the masking filter that will mask the authentic data
/// of a column for a given masking policy
///
/// * relid is the relation OID
/// * colnum is the attribute position, numbered from 1 up
/// * policy is the masking policy
///
pub fn masking_value_for_column(
    relid: pg_sys::Oid,
    colnum: i32,
    policy: String
) -> Option<String> {

    let lockmode = pg_sys::AccessShareLock as i32;

    // `pg_sys::relation_open()` will raise XX000
    // if the specified oid isn't a valid relation
    let relation = unsafe {
        PgBox::from_pg(pg_sys::relation_open(relid, lockmode))
    };

    // reldesc is a TupleDescData object
    // https://doxygen.postgresql.org/structTupleDescData.html
    let reldesc = unsafe { PgBox::from_pg(relation.rd_att) };
    let natts = reldesc.natts;
    let attrs = unsafe {
        reldesc.attrs.as_slice(natts.try_into().unwrap())
    };

    // Here attributes are numbered from 0 up
    let a = attrs[colnum as usize - 1 ];
    if a.attisdropped {
        return None;
    }

    let masking_value = value_for_att(&relation,&a,policy);

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    Some(masking_value)
}

/// Read the Security Label for a given object
///
pub fn rule(
    class_id: pg_sys::Oid,
    object_id: pg_sys::Oid,
    object_sub_id: i32,
    policy: &str
) -> Option<PgBox::<i8>> {

    let object = pg_sys::ObjectAddress {
        classId: class_id,
        objectId: object_id,
        objectSubId: object_sub_id
    };

    let policy_c_str = CString::new(policy).unwrap();
    let policy_c_ptr = policy_c_str.as_ptr();

    PgTryBuilder::new(||
        Some(unsafe {
            PgBox::from_pg(pg_sys::GetSecurityLabel(&object,policy_c_ptr))
        }))
        .catch_others(|_| None)
        .execute()
}

/// Prepare a Raw Statement object that will replace the authentic relation
///
/// * relid is the oid of the relation
/// * policy is the masking policy to apply
///
pub fn stmt_for_table(
    relid: pg_sys::Oid,
    policy: String
) -> *mut pg_sys::Node {
    let namespace = unsafe {
        pg_sys::get_namespace_name(pg_sys::get_rel_namespace(relid))
    };
    let rel_name = unsafe { pg_sys::get_rel_name(relid) };
    //spi::quote_identifier
    let query_string = format!(
        "SELECT {} FROM {}.{};",
        masking_expressions_for_table(relid, policy),
        quote_identifier(namespace),
        quote_identifier(rel_name)
    );
    debug3!("Anon: Query = {}", query_string);

    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let query_c_ptr = query_c_string.as_c_str().as_ptr() as *const c_char;

    // WARNING: This will trigger the post_parse_hook !
    let raw_parsetree_list = unsafe { pg_sys::pg_parse_query(query_c_ptr) };

    // extract the raw statement
    // this is the equivalent of the linitial_node C macro
    // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
    let raw_stmt = unsafe {
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(raw_parsetree_list, 0) as *mut pg_sys::RawStmt
        )
    };
    debug3!("Anon: Copy raw_stmt = {:#?}", raw_stmt );

    // return the statement
    raw_stmt.stmt
}

//----------------------------------------------------------------------------
// Private functions
//----------------------------------------------------------------------------

/// Check that a role is masked in the given policy
///
fn has_mask_in_policy(
    roleid: pg_sys::Oid,
    policy: &'static str
) -> bool {

    if let Some(seclabel) = rule(pg_sys::AuthIdRelationId,roleid,0,policy) {
        if seclabel.is_null() { return false; }
        let seclabel_cstr = unsafe {
            CStr::from_ptr(seclabel.as_ptr())
        };
        // return true is the security label is `MASKED`
        return re::is_match_masked(seclabel_cstr);
    }
    false
}


/// Return the value for an attribute based on its masking rule (if any),
/// which can be either:
///     - the attribute name (i.e. the authentic value)
///     - the function or value from the masking rule
///     - the default value of the column
///     - "NULL"
///
fn value_for_att(
    rel: &PgBox<pg_sys::RelationData>,
    att: &pg_sys::FormData_pg_attribute,
    policy: String,
) -> String {

    let attname = quote_name_data(&att.attname);

    // Get the masking rule, if any

    // This is similar to the ObjectAddressSubSet C macro
    // https://doxygen.postgresql.org/objectaddress_8h.html
    let columnobject = pg_sys::ObjectAddress {
        classId: pg_sys::RelationRelationId,
        objectId: rel.rd_id,
        objectSubId: att.attnum as i32,
    };
    let policy_c_str = CString::new(policy).unwrap();
    let policy_c_ptr = policy_c_str.as_ptr();
    let seclabel_c_ptr = unsafe {
        PgBox::from_pg(pg_sys::GetSecurityLabel(
            &columnobject,
            policy_c_ptr as *const c_char,
        ))
    };

    let seclabel_cstr = {
        if seclabel_c_ptr.as_ptr().is_null() {
            c_str!("")
        } else {
            unsafe { CStr::from_ptr(seclabel_c_ptr.as_ptr()) }
        }
    };

    // No masking rule found and Privacy By Default is off,
    // the authentic value is revealed
    if seclabel_cstr.is_empty() && !guc::ANON_PRIVACY_BY_DEFAULT.get() {
        return attname.to_string();
    }

    // A masking rule was found

    // Search for a masking function
    if let Some(function) = re::capture_function(seclabel_cstr) {
        if guc::ANON_STRICT_MODE.get() {
            return cast_as_regtype(function.to_string(), att.atttypid);
        }
        return function.to_string();
    }

    // Search for a masking value
    if let Some(value) = re::capture_value(seclabel_cstr) {
        if guc::ANON_STRICT_MODE.get() {
            return cast_as_regtype(value.to_string(), att.atttypid);
        }
        return value.to_string();
    }

    // The column is declared as not masked, the authentic value is shown
    if re::is_match_not_masked(seclabel_cstr) {
        return attname.to_string();
    }

    debug3!("Anon: Privacy by default is on");
    // At this stage, we know privacy_by_default is on
    // Let's try to find the default value of the column
    if att.atthasdef {
        let reldesc = unsafe {
            // reldesc is a TupleDescData object
            // https://doxygen.postgresql.org/structTupleDescData.html
            PgBox::from_pg(rel.rd_att)
        };
        debug3!("Anon: reldesc = {:#?}", reldesc);
        // loop over the constraints of relation in search of
        // the default value of this column

        let constr = unsafe {
            // constr is a TupleConstr object
            // https://doxygen.postgresql.org/structTupleConstr.html
            PgBox::from_pg(reldesc.constr)
        };
        debug3!("Anon: constr = {:#?}", constr);

        for i in 0..constr.num_defval {
            let defval = unsafe {
                //https://doxygen.postgresql.org/structAttrDefault.html
                PgBox::from_pg(constr.defval.wrapping_add(i.into()))
            };
            if defval.adnum == att.attnum {
                // Extract the textual representation of the default value of
                // this column. The default value is stored in a binary format
                let default_value_c_ptr = unsafe {
                    pg_sys::deparse_expression(
                        pg_sys::stringToNode(defval.adbin) as *mut pg_sys::Node,
                        std::ptr::null_mut::<pg_sys::List>(), // NIL
                        false,
                        false
                    ) as *mut c_char
                };
                // Convert the c_char pointer into a string
                let default_value_c_str = unsafe {
                        CStr::from_ptr(default_value_c_ptr)
                };
                return default_value_c_str.to_str().unwrap().to_string();
            }
        }
        return "NULL".to_string();
    }

    // No default value, "NULL" (the literal value) is the last possibility
    "NULL".to_string()
}

/// Return the quoted name of a NameData identifier
/// if a column is named `I`, its quoted name is `"I"`
///
#[pg_guard]
fn quote_name_data(name_data: &pg_sys::NameData) -> &str {
    quote_identifier(name_data.data.as_ptr() as *const c_char)
}

/// Return the quoted name of a string
/// if a schema is named `WEIRD_schema`, its quoted name is `"WEIRD_schema"`
///
#[pg_guard]
fn quote_identifier(ident: *const c_char) -> &'static str {
    return unsafe { CStr::from_ptr(pg_sys::quote_identifier(ident)) }
        .to_str()
        .unwrap();
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::masking::*;

    #[pg_test]
    fn test_cast_as_regtype() {
        let oid = pg_sys::Oid::from(21);
        assert_eq!( "CAST(0 AS smallint)",
                    cast_as_regtype('0'.to_string(),oid));
    }

    #[pg_test]
    fn test_get_masking_policy() {
        let batman = fixture::create_masked_role();
        let bruce  = fixture::create_unmasked_role();
        let expected = Some("anon".to_string());
        assert_eq!( get_masking_policy(batman), expected);
        assert!(get_masking_policy(bruce).is_none())
    }

    #[pg_test]
    fn test_has_mask_in_policy() {
        let batman = fixture::create_masked_role();
        let bruce  = fixture::create_unmasked_role();
        assert!( has_mask_in_policy(batman,"anon") );
        assert!( ! has_mask_in_policy(bruce,"anon") );
        assert!( ! has_mask_in_policy(batman,"does_not_exist") );
        let not_a_real_roleid = pg_sys::Oid::from(99999999);
        assert!( ! has_mask_in_policy(not_a_real_roleid,"anon") );
    }

    #[pg_test]
    fn test_init_masking_policies() {
        assert!(init_masking_policies())
    }

    #[pg_test]
    fn test_list_masking_policies() {
        assert_eq!(vec![Some("anon")],list_masking_policies());
    }

    #[pg_test]
    fn test_masking_value_for_column(){
        let relid = fixture::create_table_person();
        let policy = "anon";

        // testing the first column
        let mut result = masking_value_for_column(relid,1,policy.to_string());
        let mut expected = "firstname".to_string();
        assert_eq!(Some(expected),result);
        // testing the second column
        result = masking_value_for_column(relid,2,policy.to_string());
        expected = "CAST(NULL AS text)".to_string();
        assert_eq!(Some(expected),result);
    }

    #[pg_test]
    fn test_masking_expressions_for_table(){
        let relid = fixture::create_table_person();
        let policy = "anon";
        let result = masking_expressions_for_table(relid,policy.to_string());
        let expected = "firstname AS firstname, CAST(NULL AS text) AS lastname"
                        .to_string();
        assert_eq!(expected, result);
    }

    #[pg_test]
    fn test_rule(){
        let batman = fixture::create_masked_role();
        let bruce  = fixture::create_unmasked_role();
        assert!(rule(pg_sys::AuthIdRelationId,batman,0,"anon").is_some());
        assert!(rule(pg_sys::AuthIdRelationId,bruce,0,"anon").unwrap().is_null());
        assert!(rule(pg_sys::AuthIdRelationId,0.into(),0,"anon").unwrap().is_null());
        assert!(rule(pg_sys::AuthIdRelationId,0.into(),0,"").unwrap().is_null());
        assert!(rule(0.into(),0.into(),0,"").unwrap().is_null());
    }

    #[pg_test]
    fn test_pa_masking_stmt_for_table(){
        let relid = fixture::create_table_person();
        let policy = "anon".to_string();
        let result = unsafe {
            pgrx::nodes::node_to_string(
                stmt_for_table(relid,policy)
            ).unwrap()
        };
        assert!(result.contains("firstname"));
        assert!(result.contains("lastname"));
    }
}
