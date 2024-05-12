///
/// # Masking Engine
///

use c_str_macro::c_str;
use crate::guc;
use crate::re;
use pgrx::prelude::*;
use std::ffi::CStr;
use std::ffi::CString;
use std::os::raw::c_char;

/// Read the Security Label for a given object
///
pub fn rule(
    class_id: pg_sys::Oid,
    object_id: pg_sys::Oid,
    object_sub_id: i32,
    policy: &str
) -> Option<PgBox::<i8>>
{
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
        crate::anon::masking_expressions_for_table(relid, policy),
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

/// Return the value for an attribute based on its masking rule (if any),
/// which can be either:
///     - the attribute name (i.e. the authentic value)
///     - the function or value from the masking rule
///     - the default value of the column
///     - "NULL"
///
pub fn value_for_att(
    rel: &PgBox<pg_sys::RelationData>,
    att: &pg_sys::FormData_pg_attribute,
    policy: String,
) -> String {
    use crate::anon::cast_as_regtype;

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
/// FIXME: should not be public ?
#[pg_guard]
pub fn quote_name_data(name_data: &pg_sys::NameData) -> &str {
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



#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::tests::fixture;
    use crate::masking::*;

    #[pg_test]
    fn test_pa_get_masking_rule(){
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
