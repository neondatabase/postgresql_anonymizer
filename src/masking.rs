///
/// # Masking Engine
///

use c_str_macro::c_str;
use crate::guc;
use crate::re;
use crate::utils;
use pgrx::prelude::*;
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
        debug3!("Check if role is masked in policy '{policy}'");
        if has_mask_in_policy(roleid,policy) {
            return Some(policy.to_string());
        }
    }
    // Found nothing, return NULL
    None
}

/// Return all the registered masking policies
///
/// We can't use pg_sys::SplitGUCList(...) here because extension are not
/// allowed to define custom GUC_LIST_QUOTE variables and thus PGRX does not
/// support the GUC_LIST_INPUT. So we split the variable here with a very basic
/// approach (spaces are not handled) and we use `:` as separator to avoid
/// confusion with traditional GUC_LIST_QUOTE parameters.
///
pub fn list_masking_policies() -> Vec<&'static str> {
    use crate::label_providers::ANON_DEFAULT_MASKING_POLICY;

    let mut masking_policies = vec![ANON_DEFAULT_MASKING_POLICY];
    masking_policies.append(
        &mut re::capture_guc_list(guc::ANON_MASKING_POLICIES.get().unwrap())
    );
    masking_policies
/*
    let policies_ptr = guc::ANON_MASKING_POLICIES
                        .get()
                        .unwrap()
                        .to_bytes_with_nul()
                        .as_ptr() as *mut c_char;
    let policies_cstr = unsafe { CStr::from_ptr(policies_ptr) };
    let policies_str  = policies_cstr.to_str().unwrap();
    policies_str.split(':').collect()
*/
}


/// Returns a String and bool
///
/// The String is the "select clause filters" that will mask the authentic data
/// of a table for a given masking policy
///
/// the bool indicate is the table as at least one masked column
///
pub fn masking_expressions(
    relid: pg_sys::Oid,
    policy: String
) -> (String,bool) {
    let mut table_has_one_masked_column = false;
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
        let (filter_value, att_is_masked) = value_for_att(&relation, a, policy.clone());
        if att_is_masked { table_has_one_masked_column = true; }
        let attname_quoted = quote_name_data(&a.attname);
        let filter = format!("{filter_value} AS {attname_quoted}");
        expressions.push(filter);
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    (expressions.join(", ").to_string(), table_has_one_masked_column)
}

/// Returns the masking filters for a given table
///
/// This a wrapper around the `masking_expressions()` function used by
/// the legacy dynamic masking system. It will be dropped in version 3
///
pub fn masking_expressions_for_table(
    relid: pg_sys::Oid,
    policy: String
) -> String {
    let (masking_expressions, _) = masking_expressions(relid,policy);
    masking_expressions
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

    let (masking_value,_) = value_for_att(&relation,&a,policy);

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    Some(masking_value)
}

/// Prepare a SQL Statement object that will replace the authentic relation
///
/// * relid is the oid of the relation
/// * policy is the masking policy to apply
///
pub fn subquery( relid: pg_sys::Oid, policy: String) -> Option<String>
{
    let (masking_expressions,table_is_masked) = masking_expressions(relid, policy);

    if ! table_is_masked { return None; }

    Some(format!(
        "SELECT {} FROM {};",
        masking_expressions,
        utils::get_relation_qualified_name(relid)
    ))
}

/// Prepare a ParseTree object from a SQL query
///
pub fn parse_subquery(query_sql: String) -> PgBox<pg_sys::RawStmt>
{

    let query_c_string = CString::new(query_sql.as_str()).unwrap();
    let query_ptr = query_c_string.as_c_str().as_ptr() as *const c_char;

    let raw_parsetree_list = unsafe {
        pg_sys::pg_parse_query(query_ptr)
    };

    // extract the raw statement
    // this is the equivalent of the linitial_node C macro
    // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
    unsafe {
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(raw_parsetree_list, 0) as *mut pg_sys::RawStmt
        )
    }
}

/// Read the Security Label for a given object
///
pub fn rule(
    class_id: pg_sys::Oid,
    object_id: pg_sys::Oid,
    object_sub_id: i32,
    policy: &str
) -> Option<PgBox::<c_char>> {

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


/// Returns a string and a bool
/// the bool means whether the column is masked or not
/// the string is the value of the attribute based on its masking rule (if any),
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
) -> (String, bool) {

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
        return (attname.to_string(), false);
    }

    // A masking rule was found

    // Search for a masking function
    if let Some(function) = re::capture_function(seclabel_cstr) {
        if guc::ANON_STRICT_MODE.get() {
            return (cast_as_regtype(function.to_string(), att.atttypid),true);
        }
        return (function.to_string(), true);
    }

    // Search for a masking value
    if let Some(value) = re::capture_value(seclabel_cstr) {
        if guc::ANON_STRICT_MODE.get() {
            return (cast_as_regtype(value.to_string(), att.atttypid), true);
        }
        return (value.to_string(), true);
    }

    // The column is declared as not masked, the authentic value is shown
    if re::is_match_not_masked(seclabel_cstr) {
        return (attname.to_string(), false);
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
                return (default_value_c_str.to_str().unwrap().to_string(),true);
            }
        }
        return ("NULL".to_string(), true);
    }

    // No default value, "NULL" (the literal value) is the last possibility
    ("NULL".to_string(),true)
}

/// Return the quoted name of a NameData identifier
/// if a column is named `I`, its quoted name is `"I"`
///
fn quote_name_data(name_data: &pg_sys::NameData) -> &str {
    utils::quote_identifier(name_data.data.as_ptr() as *const c_char)
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::label_providers;
    use crate::masking::*;
    use crate::label_providers::ANON_DEFAULT_MASKING_POLICY;

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
        let expected = Some(ANON_DEFAULT_MASKING_POLICY.to_string());
        assert_eq!( get_masking_policy(batman), expected);
        assert!(get_masking_policy(bruce).is_none())
    }

    #[pg_test]
    fn test_get_multiple_policies() {
        fixture::declare_masking_policies();
        label_providers::register_label_providers();
        let devin = fixture::create_masked_role_in_policy("devin","devtests");
        let anna  = fixture::create_masked_role_in_policy("anna","analytics");
        let devtests = Some("devtests".to_string());
        let analytics = Some("analytics".to_string());
        assert_eq!( get_masking_policy(devin), devtests);
        assert_eq!( get_masking_policy(anna), analytics);
    }

    #[pg_test]
    fn test_has_mask_in_policy_anon() {
        let batman = fixture::create_masked_role();
        let bruce  = fixture::create_unmasked_role();
        assert!( has_mask_in_policy(batman,ANON_DEFAULT_MASKING_POLICY) );
        assert!( ! has_mask_in_policy(bruce,ANON_DEFAULT_MASKING_POLICY) );
        assert!( ! has_mask_in_policy(batman,"does_not_exist") );
        let not_a_real_roleid = pg_sys::Oid::from(99999999);
        assert!( ! has_mask_in_policy(not_a_real_roleid,ANON_DEFAULT_MASKING_POLICY) );
    }

    #[pg_test]
    fn test_has_mask_in_multiple_policies() {
        fixture::declare_masking_policies();
        label_providers::register_label_providers();
        let devin = fixture::create_masked_role_in_policy("devin","devtests");
        let anna  = fixture::create_masked_role_in_policy("anna","analytics");
        assert!( has_mask_in_policy(devin,"devtests") );
        assert!( ! has_mask_in_policy(devin,ANON_DEFAULT_MASKING_POLICY) );
        assert!( has_mask_in_policy(anna,"analytics") );
        assert!( ! has_mask_in_policy(anna,"devtests") );
    }

    #[pg_test]
    fn test_list_masking_policies_default() {
        assert_eq!(vec![ANON_DEFAULT_MASKING_POLICY],list_masking_policies());
    }

    #[pg_test]
    fn test_list_masking_policies_multiple() {
        fixture::declare_masking_policies();
        assert_eq!( vec![ANON_DEFAULT_MASKING_POLICY,"devtests","analytics"],
                    list_masking_policies());
    }

    #[pg_test]
    fn test_masking_value_for_column(){
        let relid = fixture::create_table_person();

        // testing the first column
        let mut result = masking_value_for_column(relid,1,ANON_DEFAULT_MASKING_POLICY.to_string());
        let mut expected = "firstname".to_string();
        assert_eq!(Some(expected),result);
        // testing the second column
        result = masking_value_for_column(relid,2,ANON_DEFAULT_MASKING_POLICY.to_string());
        expected = "CAST(NULL AS text)".to_string();
        assert_eq!(Some(expected),result);
    }


    #[pg_test]
    fn test_masking_expressions(){
        let relid = fixture::create_table_person();
        let (result,masked) = masking_expressions(relid,ANON_DEFAULT_MASKING_POLICY.to_string());
        let expected = "firstname AS firstname, CAST(NULL AS text) AS lastname"
                        .to_string();
        assert!(masked);
        assert_eq!(expected, result);

        // now with a non-existing policy
        let (result2,masked2) = masking_expressions(relid,"".to_string());
        assert!(!masked2);
        let expected2 = "firstname AS firstname, lastname AS lastname"
                        .to_string();
        assert_eq!(expected2, result2);
    }

    #[pg_test]
    fn test_masking_expressions_for_table(){
        let relid = fixture::create_table_person();
        let result = masking_expressions_for_table(relid,ANON_DEFAULT_MASKING_POLICY.to_string());
        let expected = "firstname AS firstname, CAST(NULL AS text) AS lastname"
                        .to_string();
        assert_eq!(expected, result);
    }

    #[pg_test]
    fn test_rule(){
        let batman = fixture::create_masked_role();
        let bruce  = fixture::create_unmasked_role();
        assert!(rule(pg_sys::AuthIdRelationId,batman,0,ANON_DEFAULT_MASKING_POLICY).is_some());
        assert!(rule(pg_sys::AuthIdRelationId,bruce,0,ANON_DEFAULT_MASKING_POLICY).unwrap().is_null());
        assert!(rule(pg_sys::AuthIdRelationId,0.into(),0,ANON_DEFAULT_MASKING_POLICY).unwrap().is_null());
        assert!(rule(pg_sys::AuthIdRelationId,0.into(),0,"").unwrap().is_null());
        assert!(rule(0.into(),0.into(),0,"").unwrap().is_null());
    }

    #[pg_test]
    fn test_subquery_some(){
        let relid = fixture::create_table_person();
        let result = subquery(relid,ANON_DEFAULT_MASKING_POLICY.to_string());
        assert!(result.is_some());
        assert!(result.clone().unwrap().contains("firstname"));
        assert!(result.clone().unwrap().contains("lastname"));
        let another_policy = "does_not_exist".to_string();
        let result_in_another_policy = subquery(relid,another_policy);
        assert!(result_in_another_policy.is_none());
    }

    #[pg_test]
    fn test_subquery_none(){
        let relid = fixture::create_table_call();
        let result = subquery(relid,ANON_DEFAULT_MASKING_POLICY.to_string());
        assert!(result.is_none());
    }

    #[pg_test]
    fn test_parse_subquery() {
        let relid = fixture::create_table_person();
        let subquery = subquery(relid,ANON_DEFAULT_MASKING_POLICY.to_string());
        let raw_stmt = parse_subquery(subquery.clone().unwrap());
        let result = unsafe {
            pgrx::nodes::node_to_string(raw_stmt.stmt).unwrap()
        };
        assert!(result.contains("firstname"));
        assert!(result.contains("lastname"));
    }
}
