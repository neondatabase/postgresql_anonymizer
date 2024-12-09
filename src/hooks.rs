use crate::error;
use crate::guc;
use crate::log;
use crate::masking;
use crate::utils;
use crate::walker;
use pgrx::prelude::*;


#[allow(deprecated)]
use pgrx::HookResult;

#[allow(deprecated)]
use pgrx::JumbleState;

use pgrx::list::old_list::PgList;




/// Apply masking rules to a COPY statement
/// In a COPY statement, substitute the masked relation by its masking view
///
/// For instance, the statement below :
///   COPY person TO stdout;
///
/// will be replaced by :
///
///   COPY ( SELECT * FROM "public"."person" ) TO stdout;
///
/// Later in the process, the post_parse_analyze hook will be triggered
/// and the `rewrite_walker()` function will rewrite it again like this
///
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
fn pa_rewrite_utility(pstmt: &PgBox<pg_sys::PlannedStmt>) {
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
        log::debug1!("Anon: COPY found");
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

        // ignore `COPY FROM` statements
        if copystmt.is_from { return; }

        // This is a `COPY (SELECT ...) TO` statements
        // The SELECT subquery will be masked later by the `rewrite_walker()`
        // when triggered by the post_parse_analyze hook
        if copystmt.relation.is_null() { return; }

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

        // Generate the masking subquery (aka msq)
        // Here we just replace
        //  ```
        //  COPY foo (a,b,c) TO [...]
        //  ```
        // with
        //  ```
        //  COPY (
        //     SELECT a,b,c FROM "public"."foo"
        //  ) TO [...]
        //  ```
        //
        // The SELECT subquery will be masked later by `rewrite_walker()`
        // when triggered by the post_parse_analyze hook
        //
        // The final statement will be
        //  ```
        //  COPY (
        //     SELECT a,b,c FROM (
        //         SELECT <masking_filters>
        //         FROM "public"."foo"
        //         TABLESAMPLE SYSTEM(33)
        //     ) AS foo
        //  ) TO [...]
        //  ```
        //

        let mut attributes: Vec<String> = vec![];
        let att_nodes = unsafe {
            // SAFETY: when there's no attributes, the pgList is empty
            PgList::<pg_sys::Node>::from_pg(copystmt.attlist)
        };
        for node in att_nodes.iter_ptr() {
            let attname = unsafe {
                // SAFETY : a Postgres pg_sys::List, and by extension PgList,
                // wont contain null pointer
                pgrx::node_to_string(node).unwrap()
            };
            attributes.push(attname.to_string());
        }
        if attributes.is_empty() { attributes = vec!["*".into()]; }

        let Some(relname) = utils::get_relation_qualified_name(relid)
                            else {
                                error::internal("Cannot get relation name");
                                return;
                            };
        let msq_sql = format!("SELECT {} FROM {relname}", attributes.join(","));
        let msq_raw_stmt  = masking::parse_subquery(msq_sql.clone());
        log::debug3!("Anon: COPY subquery sql = {:#?}", msq_sql);

        // Replace the relation by the masking subquery
        copystmt.relation = core::ptr::null_mut();
        copystmt.attlist = core::ptr::null_mut();
        copystmt.query = msq_raw_stmt.stmt;

        // Return the pointer to Postgres
        copystmt.into_pg();

    }
}



//----------------------------------------------------------------------------
// Hooks
//----------------------------------------------------------------------------

pub struct AnonHooks {
}

#[allow(deprecated)]
impl pgrx::hooks::PgHooks for AnonHooks {

    /// The process_utility_hook is called for each utility commands
    /// (i.e. anything other SELECT,INSERT, UPDATE,DELETE)
    ///
    /// It is used to rewrite the `COPY .. TO stdout` statements launched by
    /// pg_dump
    ///
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
        ) -> HookResult<()>,
    ) -> HookResult<()> {

        if unsafe { pg_sys::IsTransactionState() } {
            let uid = unsafe { pg_sys::GetUserId() };

            // Rewrite the utility command when transparent dynamic masking
            // is enabled and the role is masked
            if guc::ANON_TRANSPARENT_DYNAMIC_MASKING.get()
            && masking::get_masking_policy(uid).is_some() {
                pa_rewrite_utility(&pstmt);
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

    /// The post_parse_analyze hook is called after parse analyze goes,
    /// immediately after performing transformTopLevelStmt()
    /// When a masked role sends a query, the query will be "masked" using
    /// the masking rules available
    fn post_parse_analyze(
        &mut self,
        parse_state: PgBox<pg_sys::ParseState>,
        query: PgBox<pg_sys::Query>,
        jumble_state: Option<PgBox<JumbleState>>,
        prev_hook: fn(
            parse_state: PgBox<pg_sys::ParseState>,
            query: PgBox<pg_sys::Query>,
            jumble_state: Option<PgBox<JumbleState>>,
        ) -> HookResult<()>,
    ) -> HookResult<()> {
        if unsafe { pg_sys::IsTransactionState() } {
            let uid = unsafe { pg_sys::GetUserId() };
            if guc::ANON_TRANSPARENT_DYNAMIC_MASKING.get() {
                if let Some(masking_policy) = masking::get_masking_policy(uid) {
                    unsafe {
                        walker::TreeWalker::new(masking_policy).rewrite(&query);
                    }
                }
            }
        }
        // Call the previous hook (if any)
        prev_hook(parse_state, query, jumble_state)
    }

}


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use pgrx::prelude::*;
    use crate::fixture;

    //
    // The unit tests for the hooks are a bit complex because we would have
    // to create planned statements from scratch and pass them to the function.
    //
    // Alternatively, we run SQL commands just like we would do in the
    // functional tests.
    //

    #[pg_test]
    #[ignore]
    fn test_process_utility_hook(){
        fixture::create_table_person();
        fixture::create_masked_role();
        Spi::run("
            SET anon.transparent_dynamic_masking TO TRUE;
            GRANT USAGE ON SCHEMA public TO batman;
            GRANT SELECT ON ALL TABLES IN SCHEMA public TO batman;
            SET ROLE batman;
            COPY person TO stdout;
         ").unwrap();
    }

    #[pg_test]
    fn test_post_parse_analyze(){
        fixture::create_table_person();
        fixture::create_masked_role();
        Spi::run("
            SET anon.transparent_dynamic_masking TO TRUE;
            GRANT USAGE ON SCHEMA public TO batman;
            GRANT SELECT ON ALL TABLES IN SCHEMA public TO batman;
            SET ROLE batman;
            SELECT lastname IS NULL FROM person LIMIT 1;
         ").unwrap();
    }
}
