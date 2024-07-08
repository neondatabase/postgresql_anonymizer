use crate::error;
use crate::guc;
use crate::masking;
use pgrx::prelude::*;

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
    assert!(command_type == pg_sys::CmdType::CMD_UTILITY);

    unsafe {
        if pgrx::is_a(pstmt.utilityStmt, pg_sys::NodeTag::T_ExplainStmt)
        || pgrx::is_a(pstmt.utilityStmt, pg_sys::NodeTag::T_TruncateStmt)
        {
            error::insufficient_privilege("role is masked".to_string()).ereport();
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

        // ignore `COPY FROM` statements
        if copystmt.is_from { return; }

        // ignore `COPY (SELECT ...) TO` statements
        if copystmt.relation.is_null() {
            error::not_implemented_yet().ereport();
        }

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
        copystmt.query = masking::stmt_for_table(relid, policy);

        debug3!("Anon: copystmt after = {:#?}", copystmt);

        // Return the pointer to Postgres
        copystmt.into_pg();
    }
}



//----------------------------------------------------------------------------
// Hooks
//----------------------------------------------------------------------------

pub struct AnonHooks {
}

impl pgrx::hooks::PgHooks for AnonHooks {

    // Hook trigger for each utility commands (anything other SELECT,INSERT,
    // UPDATE,DELETE)
    fn process_utility_hook(
        &mut self,
        pstmt: PgBox<pg_sys::PlannedStmt>,
        query_string: &core::ffi::CStr,
        read_only_tree: Option<bool>,
        context: pg_sys::ProcessUtilityContext::Type,
        params: PgBox<pg_sys::ParamListInfoData>,
        query_env: PgBox<pg_sys::QueryEnvironment>,
        dest: PgBox<pg_sys::DestReceiver>,
        completion_tag: *mut pg_sys::QueryCompletion,
        prev_hook: fn(
            pstmt: PgBox<pg_sys::PlannedStmt>,
            query_string: &core::ffi::CStr,
            read_only_tree: Option<bool>,
            context: pg_sys::ProcessUtilityContext::Type,
            params: PgBox<pg_sys::ParamListInfoData>,
            query_env: PgBox<pg_sys::QueryEnvironment>,
            dest: PgBox<pg_sys::DestReceiver>,
            completion_tag: *mut pg_sys::QueryCompletion,
        ) -> pgrx::hooks::HookResult<()>,
    ) -> pgrx::hooks::HookResult<()> {

        if unsafe { pg_sys::IsTransactionState() } {
            let uid = unsafe { pg_sys::GetUserId() };

            // Rewrite the utility command when transparent dynamic masking
            // is enabled and the role is masked
            if guc::ANON_TRANSPARENT_DYNAMIC_MASKING.get() {
                if let Some(masking_policy) = masking::get_masking_policy(uid) {
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


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use pgrx::prelude::*;

    #[pg_test]
    #[ignore]
    fn test_pa_rewrite_utility(){
        //
        // The unit tests for pa_rewrite_utility() are a bit complex
        // to write because the function is called by the rewrite_utility hook
        // and we would have to create planned statements from scratch and
        // pass them to function.
        //
        // Alternatively, the functional tests are way simpler to write, so
        // currently we focus on them and ignore this unit test.
        //
        // See `tests/sql/copy.sql` and `test/sql/pg_dump.sql` for more details
        //
    }

}
