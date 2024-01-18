use lazy_static::lazy_static;
use pgrx::guc::*;
use pgrx::pgrx_macros::extension_sql_file;
use pgrx::prelude::*;
use pgrx::PgSqlErrorCode::*;
use regex::Regex;
use std::ffi::CStr;
use std::ffi::CString;
use std::os::raw::c_char;

mod compat;

// Load the SQL functions AFTER the rust functions
extension_sql_file!("../sql/anon.sql", finalize);

pgrx::pg_module_magic!();

//----------------------------------------------------------------------------
// GUC Variables
//----------------------------------------------------------------------------

static GUC_ANON_K_ANONYMITY_PROVIDER: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"k_anonymity\0")
    }));

static GUC_ANON_MASKING_POLICIES: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"anon\0")
    }));

static GUC_ANON_PRIVACY_BY_DEFAULT: GucSetting<bool> =
    GucSetting::<bool>::new(false);

static GUC_ANON_RESTRICT_TO_TRUSTED_SCHEMAS: GucSetting<bool> =
    GucSetting::<bool>::new(false);

static GUC_ANON_STRICT_MODE: GucSetting<bool> =
    GucSetting::<bool>::new(true);

static GUC_ANON_TRANSPARENT_DYNAMIC_MASKING: GucSetting<bool> =
    GucSetting::<bool>::new(false);

// The GUC vars below are not used in the Rust code
// but they are used in the plpgsql code

static GUC_ANON_ALGORITHM: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"sha256\0")
    }));

static GUC_ANON_SALT: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"\0")
    }));

static GUC_ANON_SOURCE_SCHEMA: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"public\0")
    }));

static GUC_ANON_MASK_SCHEMA: GucSetting<Option<&'static CStr>> =
    GucSetting::<Option<&'static CStr>>::new(Some(unsafe {
        CStr::from_bytes_with_nul_unchecked(b"mask\0")
    }));

//----------------------------------------------------------------------------
// Syntax rules
//----------------------------------------------------------------------------

lazy_static! {

    static ref RE_INDIRECT_IDENTIFIER: Regex = Regex::new(
        r"(?i)^ *(QUASI|INDIRECT) +IDENTIFIER *$"
    ).unwrap();

    static ref RE_MASKED: Regex = Regex::new(
        r"(?i)^ *MASKED *$"
    ).unwrap();

    static ref RE_MASKED_WITH_FUNCTION: Regex = Regex::new(
        r"(?i)^ *MASKED +WITH +FUNCTION +(.*) *$"
    ).unwrap();

    static ref RE_MASKED_WITH_VALUE: Regex = Regex::new(
        r"(?i)^ *MASKED +WITH +VALUE +(.*) *$"
    ).unwrap();

    static ref RE_NOT_MASKED: Regex = Regex::new(
        r"(?i)^ *NOT +MASKED *$"
    ).unwrap();

    static ref RE_TABLESAMPLE: Regex = Regex::new(
        r"(?i)^ *TABLESAMPLE +(.*) *$"
    ).unwrap();

    static ref RE_TRUSTED: Regex = Regex::new(
        r"(?i)^ *TRUSTED *$"
    ).unwrap();
}

//----------------------------------------------------------------------------
// SECURITY LABEL callbacks
//----------------------------------------------------------------------------

///
/// Checking the syntax of a k-anonymity rules
///
///
#[pg_guard]
unsafe extern "C" fn pa_k_anonymity_object_relabel(
    object_ptr: *const pg_sys::ObjectAddress,
    seclabel_ptr: *const i8,
) {
    debug1!("Anon: Checking the K-Anonymity Security Label");

    /* SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS NULL */
    if seclabel_ptr.is_null() {
        return
    }

    // Transform the object C pointer into a smart pointer
    let object = unsafe {
        PgBox::<pg_sys::ObjectAddress>::from_pg(
            object_ptr as *mut pg_sys::ObjectAddress
        )
    };

    /*
     * SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS 'INDIRECT IDENTIFIER';
     * SECURITY LABEL FOR k_anonymity ON COLUMN client.zipcode IS 'QUASI IDENTIFIER';
     */
    if object.classId == pg_sys::RelationRelationId {
        let seclabel_cstr = unsafe { CStr::from_ptr(seclabel_ptr) };
        let seclabel_str  = seclabel_cstr.to_str().unwrap();
        if RE_INDIRECT_IDENTIFIER.is_match(seclabel_str) {
            return
        }
        ereport!(
            ERROR,
            ERRCODE_INVALID_NAME,
            format!("'{}' is not a valid label for a column", seclabel_str)
        );
    }
    ereport!(
        ERROR,
        ERRCODE_FEATURE_NOT_SUPPORTED,
        "The k_anonymity provider does not support labels on this object"
    );
}


/// Checking the syntax of the a masking rule
///
/// This function is a callback called whenever a SECURITY LABEL is declared on
/// a registered masking policy
///
#[pg_guard]
unsafe extern "C" fn pa_masking_policy_object_relabel(
    object_ptr: *const pg_sys::ObjectAddress,
    seclabel_ptr: *const i8,
) {
    /* SECURITY LABEL FOR anon ON COLUMN foo.bar IS NULL */
    if seclabel_ptr.is_null() {
        return
    }

    // convert the object C pointer into a smart pointer
    let object = unsafe {
        PgBox::<pg_sys::ObjectAddress>::from_pg(
            object_ptr as *mut pg_sys::ObjectAddress
        )
    };

    // convert the C string pointer into a Rust string
    let seclabel_cstr = unsafe { CStr::from_ptr(seclabel_ptr) };
    let string_seclabel = seclabel_cstr.to_str().unwrap().to_string();

    /* Prevent SQL injection attacks inside the security label */
    let has_semicolon: bool = string_seclabel.contains(';');

    match object.classId {
        /* SECURITY LABEL FOR anon ON DATABASE d IS 'TABLESAMPLE SYSTEM(10)' */
        pg_sys::DatabaseRelationId => {
            if RE_TABLESAMPLE.is_match(&string_seclabel) && !has_semicolon {
                return
            }
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{}' is not a valid label for a database", string_seclabel)
            );
        }
        /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
        pg_sys::RelationRelationId => {
            /*
             * RelationRelationId will match either a table or a column !
             * If the object subId is 0, it's a table
             */

            /* SECURITY LABEL FOR anon ON TABLE t IS 'TABLESAMPLE SYSTEM(10)' */
            if object.objectSubId == 0 {
                if RE_TABLESAMPLE.is_match(&string_seclabel) && !has_semicolon {
                    return
                }
                ereport!(
                    ERROR,
                    ERRCODE_INVALID_NAME,
                    format!("'{}' is not a valid label for a table", string_seclabel)
                );
            } else {
                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH VALUE $x$' */
                if RE_MASKED_WITH_VALUE.is_match(&string_seclabel) {
                    return
                }

                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'MASKED WITH FUNCTION $x$' */
                if RE_MASKED_WITH_FUNCTION.is_match(&string_seclabel) {
                    return
                }
                /* SECURITY LABEL FOR anon ON COLUMN t.i IS 'NOT MASKED */
                if RE_NOT_MASKED.is_match(&string_seclabel) {
                    return
                }
                ereport!(
                    ERROR,
                    ERRCODE_INVALID_NAME,
                    format!("'{}' is not a valid label for a column", string_seclabel)
                );
            }
        }

        /* SECURITY LABEL FOR anon ON ROLE batman IS 'MASKED' */
        pg_sys::AuthIdRelationId => {
            if RE_MASKED.is_match(&string_seclabel) {
                return
            }
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{}' is not a valid label for a role", string_seclabel)
            );
        }
        /* SECURITY LABEL FOR anon ON SCHEMA public IS 'TRUSTED' */
        pg_sys::NamespaceRelationId => {
            if !pg_sys::superuser() {
                ereport!(
                    ERROR,
                    ERRCODE_INSUFFICIENT_PRIVILEGE,
                    "only superuser can set an anon label for a schema"
                );
            }
            if RE_TRUSTED.is_match(&string_seclabel) {
                return
            }
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{}' is not a valid label for a schema", string_seclabel)
            );
        }

        /* Everything else is not supported */
        _ => {
            ereport!(
                ERROR,
                ERRCODE_FEATURE_NOT_SUPPORTED,
                "The anon extension does not support labels on this object"
            );
        }
    }
}


//----------------------------------------------------------------------------
// Internal Functions
//----------------------------------------------------------------------------


/// check that an expression is a valid masking function
///
/// The function does not return false, but throws a Postgres error if a value
/// expression is incorrect
///
fn pa_check_function( expr: &str) -> bool {
    use std::ptr;

    let func = pa_parse_expression(expr).expect("expression should be valid");
    debug1!("Anon: value.type_ = {:#?}", func.type_ );
    if ! unsafe {
        pgrx::is_a(func.as_ptr(),pg_sys::NodeTag::T_FuncCall)
    } {
        ereport!(
            ERROR,
            ERRCODE_SYNTAX_ERROR,
            format!("{expr} is not a correct masking function")
        );
    }

    // Walk through the parse tree and the function itself and all other
    // functions used as parameters belong to a trusted schema.
    // The goal is to block privilege escalation attacks using something like:
    //
    // `MASKED WITH FUNCTION pg_catalog.upper(public.elevate())`
    //

    ! pa_has_untrusted_schema(func.as_ptr(),ptr::null_mut())

}

#[pg_guard]
extern "C" fn pa_has_untrusted_schema(   node: *mut pg_sys::Node,
                        context: *mut ::core::ffi::c_void
) -> bool {

    if node.is_null() { return false ; }

    if unsafe {
        pgrx::is_a(node,pg_sys::NodeTag::T_FuncCall)
    } {
        let fc = unsafe {
            PgBox::from_pg(node as *mut pg_sys::FuncCall)
        };
        // fc.funcname is a pointer to a pg_sys::List
        let funcname = unsafe {
            PgBox::from_pg(fc.funcname)
        };

        if funcname.length == 2 {
            // the function name is qualified, the first element of the list
            // is the schema name
            let schema_val = unsafe {
                PgBox::from_pg(
                    pg_sys::pgrx_list_nth(funcname.as_ptr(), 0)
                    as *mut crate::compat::SchemaValue
                )
            };
            let schema_c_ptr=unsafe{crate::compat::strVal(*schema_val)};
            let schema_c_str = unsafe {CStr::from_ptr(schema_c_ptr)};
            let schema_str=schema_c_str.to_str().unwrap();
            if schema_str!="anon" {
                return true;
            }
        }
    }
    unsafe {
        pg_sys::raw_expression_tree_walker( node,
                                        Some(pa_has_untrusted_schema),
                                        context)
    }
}



/// Prepare a Raw Statement object that will replace the authentic relation
///
/// * relid is the oid of the relation
/// * policy is the masking policy to apply
///
fn pa_masking_stmt_for_table(
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
        pa_quote_identifier(namespace),
        pa_quote_identifier(rel_name)
    );
    debug3!("Anon: Query = {}", query_string);

    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let query_c_ptr = query_c_string.as_c_str().as_ptr() as *const c_char;

    // WARNING: This will trigger the post_parse_hook !
    let raw_parsetree_list = unsafe { pg_sys::pg_parse_query(query_c_ptr) };

    // extract the raw statement
    let raw_stmt = unsafe {
        // this is the equivalent of the linitial_node C macro
        // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
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
///     - the defaut value of the column
///     - "NULL"
///
fn pa_masking_value_for_att(
    rel: &PgBox<pg_sys::RelationData>,
    att: &pg_sys::FormData_pg_attribute,
    policy: String,
) -> String {
    let attname = pa_quote_name_data(&att.attname);

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

    let seclabel = {
        if seclabel_c_ptr.as_ptr().is_null() {
            ""
        } else {
            let seclabel_c_str = unsafe {
                    CStr::from_ptr(seclabel_c_ptr.as_ptr())
            };
            seclabel_c_str.to_str().unwrap()
        }
    };
    debug3!("Anon: seclabel = {seclabel}");

    // No masking rule found and Privacy By Default is off,
    // the authentic value is revealed
    if seclabel.is_empty() && !GUC_ANON_PRIVACY_BY_DEFAULT.get() {
        return attname.to_string();
    }

    // A masking rule was found

    // Search a masking function
    let caps_function = RE_MASKED_WITH_FUNCTION.captures(seclabel);
    if caps_function.is_some() {
        let function = caps_function.unwrap().get(1).unwrap().as_str().to_string();
        if GUC_ANON_STRICT_MODE.get() {
            return crate::anon::cast_as_regtype(function, att.atttypid);
        }
        return function;
    }

    // Search for a masking value
    let caps_value = RE_MASKED_WITH_VALUE.captures(seclabel);
    if caps_value.is_some() {
        let value = caps_value.unwrap().get(1).unwrap().as_str().to_string();
        if GUC_ANON_STRICT_MODE.get() {
            return crate::anon::cast_as_regtype(value, att.atttypid);
        }
        return value;
    }

    // The column is declared as not masked, the authentic value is show
    if RE_NOT_MASKED.is_match(seclabel) {
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
        // the default value of this colum

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

// Parse a given expression and return its raw statement
//
fn pa_parse_expression(expr: &str) -> Option<PgBox<pg_sys::Node>>
{
    if expr.is_empty() {
        ereport!(ERROR,
                 ERRCODE_NULL_VALUE_NOT_ALLOWED,
                 format!("expression is empty")
        );
    }

    let query_string = format!("SELECT {expr}");
    let query_c_string = CString::new(query_string.as_str()).unwrap();
    let raw_parsetree_list = unsafe {
        crate::compat::raw_parser(
            query_c_string.as_c_str().as_ptr()
            as *const pgrx::ffi::c_char
        )
    };

    // Only one statement in the parsetree is allowed
    if unsafe { raw_parsetree_list.as_ref().unwrap().length > 1 } {
        ereport!(ERROR,
                 ERRCODE_SYNTAX_ERROR,
                 format!("expression is not correct")
        );
    }
    let raw_stmt = unsafe {
        // this is the equivalent of the linitial_node C macro
        // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(raw_parsetree_list, 0)
            as *mut pg_sys::RawStmt
        )
    };

    let stmt = unsafe {
        PgBox::from_pg( raw_stmt.stmt as *mut pg_sys::SelectStmt )
    };

    // Only one expression in the target is allowed
    if unsafe { stmt.targetList.as_ref().unwrap().length > 1 } {
        ereport!(ERROR,
                 ERRCODE_SYNTAX_ERROR,
                 format!("expression is not correct")
        );
    }

    let restarget = unsafe {
        PgBox::from_pg(
            pg_sys::pgrx_list_nth(stmt.targetList, 0)
            as *mut pg_sys::ResTarget
        )
    };

    Some(unsafe { PgBox::from_pg( restarget.val as *mut pg_sys::Node ) })
}


/// Return the quoted name of a NameData identifier
/// if a column is named `I`, its quoted name is `"I"`
///
#[pg_guard]
fn pa_quote_name_data(name_data: &pg_sys::NameData) -> &str {
    pa_quote_identifier(name_data.data.as_ptr() as *const c_char)
}

/// Return the quoted name of a string
/// if a schema is named `WEIRD_schema`, its quoted name is `"WEIRD_schema"`
///
#[pg_guard]
fn pa_quote_identifier(ident: *const c_char) -> &'static str {
    return unsafe { CStr::from_ptr(pg_sys::quote_identifier(ident)) }
        .to_str()
        .unwrap();
}


/// Apply masking rules to a COPY statement
/// In a COPY statement, substitute the masked relation by its masking view
///
/// For instance, the statement below :
///   COPY person TO stdout;
///
/// will be replaced by :
///   COPY (
///       SELECT firstname AS firstname,
///              CAST(NULL AS text) AS lastname
///       FROM person
///   ) TO stdout;
///
/// Arguments:
/// * `pstmt` is the utility statement
/// * `policy` is the masking policy to apply
///
fn pa_rewrite_utility(pstmt: &PgBox<pg_sys::PlannedStmt>, policy: String) {
    let command_type = pstmt.commandType;
    assert!(command_type == pg_sys::CmdType_CMD_UTILITY);

    unsafe {
        if pgrx::is_a(pstmt.utilityStmt, pg_sys::NodeTag::T_ExplainStmt)
        || pgrx::is_a(pstmt.utilityStmt, pg_sys::NodeTag::T_TruncateStmt)
        {
            ereport!(ERROR, ERRCODE_INSUFFICIENT_PRIVILEGE, "role is masked");
        }
    }

    if unsafe { pgrx::is_a(pstmt.utilityStmt, pg_sys::NodeTag::T_CopyStmt) } {
        debug1!("Anon: COPY found");
        // The utilityStmt is provided as a pointer to a generice Node
        // But we now know that this Node is a CopyStmt
        // So we cast the Node pointer as a CopyStmt pointer to access the
        // CopyStmt properties
        //
        // see https://doxygen.postgresql.org/structCopyStmt.html
        //
        let mut copystmt = unsafe {
            PgBox::from_pg( pstmt.utilityStmt as *mut pg_sys::CopyStmt )
        };
        debug3!("Anon: copystmt before = {:#?}", copystmt );

        if ! copystmt.is_from && ! copystmt.relation.is_null() {
            // We now know this is a `COPY xxx TO ...` statement

            // Fetch the relation id
            let relid = unsafe {
                pg_sys::RangeVarGetRelidExtended(
                    copystmt.relation,
                    pg_sys::AccessShareLock as i32,
                    0,
                    None,
                    core::ptr::null_mut(),
                )
            };

            // Replace the relation by the masking subquery */
            copystmt.relation = core::ptr::null_mut();
            copystmt.attlist = core::ptr::null_mut();
            copystmt.query = pa_masking_stmt_for_table(relid, policy);

            debug3!("Anon: copystmt after = {:#?}", copystmt);

            // Return the pointer to Postgres
            copystmt.into_pg();
        }
    }
}


//----------------------------------------------------------------------------
// External Functions
//----------------------------------------------------------------------------

// All external functions are defined in the anon schema

#[pg_schema]
mod anon {
    use pgrx::prelude::*;
    use pgrx::PgSqlErrorCode::*;
    use std::ffi::CStr;
    use std::ffi::CString;

    /// Decorate a value with a CAST function
    ///
    /// Example: the value `1` will be transformed into `CAST(1 AS INT)`
    ///
    /// * value is the value to transform
    /// * atttypid is the id of the type for this data
    ///
    #[pg_extern]
    pub fn cast_as_regtype(value: String, atttypid: pg_sys::Oid) -> String {
        let type_be = unsafe { CStr::from_ptr(pg_sys::format_type_be(atttypid)) }
            .to_str()
            .unwrap();
        format!("CAST({value} AS {type_be})")
    }

    #[pg_extern]
    pub fn check_function(expr: &str) -> bool {
        crate::pa_check_function(expr)
    }

    /// Given a function call (e.g. 'anon.fake_city()'), return the namespace
    /// the function (e.g. 'anon') if possible
    ///
    /// * returns the schema name if the function is properly schema-qualified
    /// * returns an empty string if we can't find the schema name
    ///
    /// We're calling the parser to split the function call into a "raw parse tree".
    /// At this stage, there's no way to know if the schema does really exists. We
    ///  simply deduce the schema name as it is provided.
    ///
    #[pg_extern]
    pub fn get_function_schema(function_call: String) -> String {
        if function_call.is_empty() {
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("function call is empty")
            );
        }
        // build a simple SELECT statement and parse it
        let query_string = format!("SELECT {function_call}");
        let query_c_string = CString::new(query_string.as_str()).unwrap();
        let raw_parsetree_list = unsafe {
            crate::compat::raw_parser(
                query_c_string.as_c_str().as_ptr() as *const pgrx::ffi::c_char
            )
        };

        // walk throught the parse tree, down to the FuncCall node (if present)
        let raw_stmt = unsafe {
            // this is the equivalent of the linitial_node C macro
            // https://doxygen.postgresql.org/pg__list_8h.html#a213ac28ac83471f2a47d4e3918f720b4
            PgBox::from_pg(
                pg_sys::pgrx_list_nth(raw_parsetree_list, 0)
                as *mut pg_sys::RawStmt
            )
        };

        let stmt = unsafe {
            PgBox::from_pg( raw_stmt.stmt as *mut pg_sys::SelectStmt )
        };

        let restarget = unsafe {
            PgBox::from_pg(
                pg_sys::pgrx_list_nth(stmt.targetList, 0)
                as *mut pg_sys::ResTarget
            )
        };

        if !unsafe { pgrx::is_a(restarget.val, pg_sys::NodeTag::T_FuncCall) } {
            ereport!(
                ERROR,
                ERRCODE_INVALID_NAME,
                format!("'{function_call}' is not a valid function call")
            );
        }

        // if the function name is qualified, extract and return the schema name
        // https://github.com/postgres/postgres/blob/master/src/include/nodes/parsenodes.h#L413
        let fc = unsafe {
            PgBox::from_pg(restarget.val as *mut pg_sys::FuncCall)
        };
        // fc.funcname is a pointer to a pg_sys::List
        let funcname = unsafe {
            PgBox::from_pg(fc.funcname)
        };

        if funcname.length == 2 {
            // the function name is qualified, the first element of the list
            // is the schema name
            let schema_val = unsafe {
                PgBox::from_pg(
                    pg_sys::pgrx_list_nth(funcname.as_ptr(), 0)
                    as *mut crate::compat::SchemaValue
                )
            };

            // at this point, the schema name is a raw string
            // i.e if function_call is `"A".foo`, then schema_val is `"A"`
            // we return the unquoted value `A`
            let schema_string: String = format!("{}", schema_val);
            return quoted_string::strip_dquotes(&schema_string).unwrap().to_string();

        }

        // found nothing, so return an empty string
        "".to_string()
    }

    /// For a given role, returns the policy in which he/she is masked
    /// or the NULL if the role is not masked.
    ///
    /// * roleid is the id of the user we want to mask
    ///
    #[pg_extern]
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

    /// Check that a role is masked in the given policy
    ///
    #[pg_extern]
    pub fn has_mask_in_policy(
        roleid: pg_sys::Oid,
        policy: &'static str
    ) -> bool {
        use crate::RE_MASKED;

        // This is similar to the ObjectAddressSet C macro
        // https://doxygen.postgresql.org/objectaddress_8h.html
        let roleobject = pg_sys::ObjectAddress {
            classId: pg_sys::AuthIdRelationId,
            objectId: roleid,
            objectSubId: 0,
        };
        let policy_c_str = CString::new(policy).unwrap();
        let policy_c_ptr = policy_c_str.as_ptr();
        let seclabel_c_ptr = unsafe {
            PgBox::from_pg(pg_sys::GetSecurityLabel(
                &roleobject,
                policy_c_ptr,
            ))
        };
        if seclabel_c_ptr.is_null() {
            // No security label on this role
            return false;
        }

        debug3!("Anon seclabel_c_ptr = {:#?}",seclabel_c_ptr);
        let seclabel_c_str = unsafe { CStr::from_ptr(seclabel_c_ptr.as_ptr()) };
        let seclabel_str = seclabel_c_str.to_str().unwrap();

        // return true is the security label is `MASKED`
        RE_MASKED.is_match(seclabel_str)
    }

    ///
    /// Initialize the extension
    ///
    /// /!\ this function was called `anon_init` in the C implementation
    ///
    #[pg_extern]
    pub fn init_masking_policies() -> bool {
        // TODO: we should probably get rid of this function and state that
        // anon and pg_catalog are always trusted.

        // For some reasons, this can't be done int PG_init()
        for _policy in list_masking_policies().iter() {
            Spi::run("SECURITY LABEL FOR anon ON SCHEMA anon IS 'TRUSTED'")
                .expect("SPI Failed to set schema anon as trusted");
            Spi::run("SECURITY LABEL FOR anon ON SCHEMA pg_catalog IS 'TRUSTED'")
                .expect("SPI Failed to set schema pg_catalog as trusted");
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
    #[pg_extern]
    pub fn list_masking_policies() -> Vec<Option<&'static str>> {
        // transform the GUC (CStr pointer) into a Rust String
        let masking_policies = crate::GUC_ANON_MASKING_POLICIES.get()
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
    #[pg_extern]
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
            let filter_value = crate::pa_masking_value_for_att(&relation, a, policy.clone());
            let attname_quoted = crate::pa_quote_name_data(&a.attname);
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
   #[pg_extern]
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

        // Here attibutes are numbered from 0 up
        let a = attrs[colnum as usize - 1 ];

        if a.attisdropped {
            return None;
        }

        let masking_value = crate::pa_masking_value_for_att(&relation,&a,policy);

        // pass the relation back to Postgres
        unsafe {
            pg_sys::relation_close(relation.as_ptr(), lockmode);
        }

        Some(masking_value)
    }

}

//----------------------------------------------------------------------------
// Hooks
//----------------------------------------------------------------------------

static mut HOOKS: AnonHooks = AnonHooks {
};

struct AnonHooks {
}

impl pgrx::hooks::PgHooks for AnonHooks {

    // Hook trigger for each utility commands (anything other SELECT,INSERT,
    // UPDATE,DELETE)
    fn process_utility_hook(
        &mut self,
        pstmt: PgBox<pg_sys::PlannedStmt>,
        query_string: &core::ffi::CStr,
        read_only_tree: Option<bool>,
        context: pg_sys::ProcessUtilityContext,
        params: PgBox<pg_sys::ParamListInfoData>,
        query_env: PgBox<pg_sys::QueryEnvironment>,
        dest: PgBox<pg_sys::DestReceiver>,
        completion_tag: *mut pg_sys::QueryCompletion,
        prev_hook: fn(
            pstmt: PgBox<pg_sys::PlannedStmt>,
            query_string: &core::ffi::CStr,
            read_only_tree: Option<bool>,
            context: pg_sys::ProcessUtilityContext,
            params: PgBox<pg_sys::ParamListInfoData>,
            query_env: PgBox<pg_sys::QueryEnvironment>,
            dest: PgBox<pg_sys::DestReceiver>,
            completion_tag: *mut pg_sys::QueryCompletion,
        ) -> pgrx::hooks::HookResult<()>,
    ) -> pgrx::hooks::HookResult<()> {

        use crate::anon::get_masking_policy;

        if unsafe { pg_sys::IsTransactionState() } {
            let uid = unsafe { pg_sys::GetUserId() };

            // Rewrite the utility command when transparent dynamic masking
            // is enabled and the role is masked
            if GUC_ANON_TRANSPARENT_DYNAMIC_MASKING.get() {
                if let Some(masking_policy) = get_masking_policy(uid) {
                    pa_rewrite_utility(&pstmt,masking_policy);
                }
            }
        }

        // Call the previous hook (if any)
        prev_hook(
            pstmt,
            query_string,
            read_only_tree,
            context,
            params,
            query_env,
            dest,
            completion_tag,
        )
    }
}


//----------------------------------------------------------------------------
// Initialization
//----------------------------------------------------------------------------

/// _PG_init() is called when the module is loaded, not when the extension
/// is created. There is presently no way to unload a loaded module.
///
/// # Safety
///
/// The `#[pg_guard]` macro ensures that Rust `panic!()` and Postgres
/// `elog(ERROR)` are properly handled by PGRX. So even if the `extern 'C'
/// functions are declared `unsafe`, they are actually "less unsafe"  than some
/// C functions because of this guard.
///
#[pg_guard]
pub unsafe extern "C" fn _PG_init() {
    pgrx::hooks::register_hook(&mut HOOKS);

    GucRegistry::define_string_guc(
        "anon.k_anonymity_provider",
        "The security label provider used for k-anonymity",
        "",
        &GUC_ANON_K_ANONYMITY_PROVIDER,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.masking_policies",
        "Define multiple masking policies (NOT IMPLEMENTED YET)",
        "",
        &GUC_ANON_MASKING_POLICIES,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY, /* GUC_LIST_INPUT is not available ? */
    );

    GucRegistry::define_bool_guc(
        "anon.privacy_by_default",
        "Mask all columns with NULL (or the default value for NOT NULL columns)",
        "",
        &GUC_ANON_PRIVACY_BY_DEFAULT,
        GucContext::Suset,
        GucFlags::default(),
    );


   GucRegistry::define_bool_guc(
        "anon.transparent_dynamic_masking",
        "New masking engine (EXPERIMENTAL)",
        "",
        &GUC_ANON_TRANSPARENT_DYNAMIC_MASKING,
        GucContext::Suset,
        GucFlags::default(),
    );

    GucRegistry::define_bool_guc(
        "anon.restrict_to_trusted_schemas",
        "Masking filters must be in a trusted schema",
        "Activate this option to prevent non-superuser from using their own masking filters",
        &GUC_ANON_RESTRICT_TO_TRUSTED_SCHEMAS,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_bool_guc(
        "anon.strict_mode",
        "A masking rule cannot change a column data type, unless you disable this",
        "Disabling the mode is not recommended",
        &GUC_ANON_STRICT_MODE,
        GucContext::Suset,
        GucFlags::default(),
    );


    // The GUC vars below are not used in the Rust code
    // but they are used in the plpgsql code

    GucRegistry::define_string_guc(
        "anon.algorithm",
        "The hash method used for pseudonymizing functions",
        "",
        &GUC_ANON_ALGORITHM,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.maskschema",
        "The schema where the dynamic masking views are stored",
        "",
        &GUC_ANON_MASK_SCHEMA,
        GucContext::Suset,
        GucFlags::default(),
    );

    GucRegistry::define_string_guc(
        "anon.salt",
        "The salt value used for the pseudonymizing functions",
        "",
        &GUC_ANON_SALT,
        GucContext::Suset,
        GucFlags::SUPERUSER_ONLY,
    );

    GucRegistry::define_string_guc(
        "anon.sourceschema",
        "The schema where the table are masked by the dynamic masking engine",
        "",
        &GUC_ANON_SOURCE_SCHEMA,
        GucContext::Suset,
        GucFlags::default(),
    );

    // Register the security label provider for k-anonymity
    pg_sys::register_label_provider(
        GUC_ANON_K_ANONYMITY_PROVIDER
            .get()
            .unwrap()
            .to_bytes_with_nul()
            .as_ptr() as *const i8,
        Some(pa_k_anonymity_object_relabel),
    );

    // Register the masking policies
    for policy in anon::list_masking_policies().iter() {
        debug1!("Anon: registering masking policy '{}'", policy.unwrap());
        // transform the str back into a C Pointer
        let c_ptr_policy = policy.unwrap().as_ptr();
        unsafe {
            pg_sys::register_label_provider(
                c_ptr_policy as *const i8,
                Some(pa_masking_policy_object_relabel),
            )
        }
    }

    debug1!("Anon: extension initialized");

}


//----------------------------------------------------------------------------
// Unit tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use pgrx::prelude::*;
    use regex::Regex;

    //
    // Create objects for testing purpose
    // This is a very basic context. For more sophisticated use cases, use the
    // functionnal tests
    //
    fn create_masked_role() -> pg_sys::Oid {
        Spi::run("
            CREATE ROLE batman;
            SECURITY LABEL FOR anon ON ROLE batman is 'MASKED';
        ").unwrap();
        Spi::get_one::<pg_sys::Oid>("SELECT 'batman'::REGROLE::OID;")
            .unwrap()
            .expect("should be an OID")
    }

    fn create_table_person() -> pg_sys::Oid {
        Spi::run("
            CREATE TABLE person AS
                SELECT  'Sarah'::VARCHAR(30)        AS firstname,
                        'Connor'::TEXT              AS lastname
            ;

            SECURITY LABEL FOR anon ON COLUMN person.lastname
                IS 'MASKED WITH VALUE NULL';
        ").unwrap();

        Spi::get_one::<pg_sys::Oid>("SELECT 'person'::REGCLASS::OID")
            .unwrap()
            .expect("should be an OID")
    }


    fn create_unmasked_role() -> pg_sys::Oid {
        Spi::run("
            CREATE ROLE bruce;
        ").unwrap();
        Spi::get_one::<pg_sys::Oid>("SELECT 'bruce'::REGROLE::OID;")
            .unwrap()
            .expect("should be an OID")
    }

    //
    // Testing external functions
    //

    #[pg_test]
    fn test_anon_cast_as_regtype() {
        let oid = pg_sys::Oid::from(21);
        assert_eq!( "CAST(0 AS smallint)",
                    crate::anon::cast_as_regtype('0'.to_string(),oid));
    }

    #[pg_test]
    fn test_anon_get_function_schema() {
        use crate::anon::get_function_schema;
        assert_eq!("a",get_function_schema("a.b()".to_string()));
        assert_eq!("", get_function_schema("publicfoo()".to_string()));
    }

    #[pg_test(error = "function call is empty")]
    fn test_anon_get_function_schema_error_empty() {
        use crate::anon::get_function_schema;
        get_function_schema("".to_string());
    }

    #[pg_test(error = "'foo' is not a valid function call")]
    fn test_anon_get_function_schema_error_invalid() {
        use crate::anon::get_function_schema;
        get_function_schema("foo".to_string());
    }

    #[pg_test]
    fn test_anon_get_masking_policy() {
        use crate::anon::get_masking_policy;
        let expected = Some("anon".to_string());
        assert_eq!( get_masking_policy(create_masked_role()), expected);
        assert!(get_masking_policy(create_unmasked_role()).is_none())
    }

    #[pg_test]
    fn test_anon_has_mask_in_policy() {
        use crate::anon::has_mask_in_policy;
        let batman = create_masked_role();
        let bruce  = create_unmasked_role();
        assert!( has_mask_in_policy(batman,"anon") );
        assert!( ! has_mask_in_policy(bruce,"anon") );
        assert!( ! has_mask_in_policy(batman,"does_not_exists") );
        let not_a_real_roleid = pg_sys::Oid::from(99999999);
        assert!( ! has_mask_in_policy(not_a_real_roleid,"anon") );
    }

    #[pg_test]
    fn test_anon_list_masking_policies() {
        use crate::anon::list_masking_policies;
        assert_eq!(vec![Some("anon")],list_masking_policies());
    }

    #[pg_test]
    fn test_anon_masking_expressions_for_table(){
        use crate::anon::masking_expressions_for_table;
        let relid = create_table_person();
        let policy = "anon";
        let result = masking_expressions_for_table(relid,policy.to_string());
        let expected = "firstname AS firstname, CAST(NULL AS text) AS lastname"
                        .to_string();
        assert_eq!(expected, result);
    }


    #[pg_test]
    fn test_anon_masking_value_for_column(){
        use crate::anon::masking_value_for_column;
        let relid = create_table_person();
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

    //
    // Testing Internal functions
    //

    #[pg_test]
    fn test_pa_masking_stmt_for_table(){
        use crate::pa_masking_stmt_for_table;
        let relid = create_table_person();
        let policy = "anon".to_string();
        let result = unsafe {
            pgrx::nodes::node_to_string(
                pa_masking_stmt_for_table(relid,policy)
            ).unwrap()
        };
        assert!(result.contains("firstname"));
        assert!(result.contains("lastname"));
    }


    #[pg_test]
    #[ignore]
    fn test_pa_rewrite_utility(){
        //
        // The unit tests for pa_rewrite_utility() are a bit complex
        // to write because the function is called by the rewrite_utility hook
        // and we would have to create planned statements from scratch and
        // pass them to function.
        //
        // Alternatively, the functionnal tests are way simpler to write, so
        // currenlty we focus on them and ignore this unit test.
        //
        // See `tests/sql/copy.sql` and `test/sql/pg_dump.sql` for more details
        //
    }

    //
    // Testing regular expressions
    //
    // /!\ each lazy_static constant has its own type, so it needs to be
    // dereferenced with `&*` when passed to this function
    // see https://github.com/rust-lang-nursery/lazy-static.rs/issues/119
    //
    fn check_regex(r: &Regex, correct: Vec<&str>, incorrect: Vec<&str>) {
        let mut count = 0;
        for i in &incorrect {
            count += r.is_match(i) as i32;
        }
        assert_eq!(count, 0);
        for c in &correct {
            count += r.is_match(c) as i32;
        }
        assert_eq!(count, correct.len() as i32);
    }

    #[pg_test]
    fn test_regex_indirect_identifier() {
        let correct   = vec![ "INDIRECT IDENTIFIER",
                              "quasi identifier",
                              " QuAsI    idenTIFIER  " ];
        let incorrect = vec![ "IDENTIFIER",
                              "quasi-identifier" ];
        check_regex( &*crate::RE_INDIRECT_IDENTIFIER,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_masked() {
        let correct   = vec![ "MASKED",
                              "  MaSKeD       " ];
        let incorrect = vec![ "MAKSED"];
        check_regex( &*crate::RE_MASKED,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_masked_with_function() {
        let correct   = vec![ "MASKED WITH FUNCTION public.foo()",
                              " masked  WITH funCTION bar(0,$$y$$) " ];
        let incorrect = vec![ "MASKED WITH FUNCTION",
                              "MASKED WITH public.foo()" ];
        check_regex( &*crate::RE_MASKED_WITH_FUNCTION,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_masked_with_value() {
        let correct   = vec![ "MASKED WITH VALUE $$zero$$",
                              " masked  WITH vaLue  NULL " ];
        let incorrect = vec![ "MASKED WITH VALUE",
                              "MASKED WITH 0" ];
        check_regex( &*crate::RE_MASKED_WITH_VALUE,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_not_masked() {
        let correct   = vec![ "NOT MASKED",
                              "NOT    MASKED",
                              "not masked",
                              " NoT MaSkED " ];
        let incorrect = vec![ "NOTMASKED" ];
        check_regex( &*crate::RE_NOT_MASKED,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_tablesample() {
        let correct   = vec![ "TABLESAMPLE SYSTEM(10)'",
                              "  tablesample system(10)  "];
        let incorrect = vec![ "TABLESAMPLE"];
        check_regex( &*crate::RE_TABLESAMPLE,correct,incorrect);
    }

    #[pg_test]
    fn test_regex_trusted() {
        let correct   = vec![ "TRUSTED",
                              "     trusted " ];
        let incorrect = vec![ "TRUSTTED",];
        check_regex( &*crate::RE_TRUSTED,correct,incorrect);
    }
}

/// This module is required by `cargo pgrx test` invocations.
/// It must be visible at the root of your extension crate.
#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {
        // perform one-off initialization when the pg_test framework starts
    }

    pub fn postgresql_conf_options() -> Vec<&'static str> {
        // return any postgresql.conf settings that are required for your tests
        vec![]
    }
}
