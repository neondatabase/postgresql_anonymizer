///
/// # Replica Masking
///
use crate::guc;
use crate::log;
use crate::masking;
use crate::utils;
use pgrx::prelude::*;

/// Return the SQL assignments which will mask the data in a trigger
///
/// ## Example:
///
/// * if a column `fk_user` is masked with `pg_catalog.md5(fk_user)`
/// * the assignment will look like this
///
/// NEW.fk_user = (SELECT CAST(pg_catalog.md5(fk_user) AS text) FROM (SELECT NEW.* ) AS n);
///
fn trigger_new_assignments(relid: pg_sys::Oid, policy: String) -> Option<String> {
    let lockmode = pg_sys::AccessShareLock as i32;

    // SAFETY: `pg_sys::relation_open()` will raise XX000 if the specified oid
    // isn't a valid relation
    let relation = unsafe { PgBox::from_pg(pg_sys::relation_open(relid, lockmode)) };

    // reldesc is a TupleDescData object
    // https://doxygen.postgresql.org/structTupleDescData.html
    let reldesc = unsafe { PgBox::from_pg(relation.rd_att) };
    let natts = reldesc.natts;
    let attrs = unsafe { reldesc.attrs.as_slice(natts.try_into().unwrap()) };

    let mut assignments = Vec::new();
    for a in attrs {
        if a.attisdropped {
            continue;
        }

        let (filter_value, att_is_masked) = masking::value_for_att(&relation, a, policy.clone());

        // Typically in a for a NEW assignment (INSERT or UPDATE),
        // we only want to overwrite the value of the masked columns
        if att_is_masked {
            assignments.push(format!(
                "NEW.{:?} = (SELECT {} FROM (SELECT NEW.* ) AS n);",
                name_data_to_str(&a.attname),
                filter_value
            ));
        }
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    if assignments.is_empty() {
        return None;
    }
    Some(assignments.join(" ").to_string())
}

/// Remove the masking trigger from a table
pub fn drop_replica_trigger_for_table(relid: pg_sys::Oid) -> Option<bool> {
    let tablename = utils::get_relation_qualified_name(relid)?;
    let relint: u32 = relid.into();

    let sql: String = format_args!(
        include_str!("templates/sql/drop_replica_trigger.sql"),
        relint = relint,
        tablename = tablename,
    )
    .to_string();

    log::debug1!("Anon: {sql}");
    Spi::run(&sql)
        .unwrap_or_else(|_| panic!("Failed to drop replica masking triggers for {tablename}"));

    Some(true)
}

/// Create the masking trigger for a given table in a given policy
///
/// IMPORTANT: this function is not transactionnal !
///
/// The spi::run call will open a new session which means that when the
/// refresh is launched within a transaction, all objects created previously
/// in that transaction (especially tables and security labels) are NOT visible
/// yet for the `create_replica_trigger` script.
///
pub fn refresh_replica_trigger_for_table(relid: pg_sys::Oid, policy: String) -> Option<bool> {
    if !guc::ANON_REPLICA_MASKING.get() {
        return Some(false);
    }

    let tablename = utils::get_relation_qualified_name(relid)?;

    let sql: String = format_args!(
        include_str!("templates/sql/create_replica_trigger.sql"),
        relint = relid,
        tablename = tablename,
        new_assignments = trigger_new_assignments(relid, policy.clone())?,
        random = fastrand::u8(..),
    )
    .to_string();

    log::debug1!("Anon: {sql}");

    Spi::run(&sql)
        .unwrap_or_else(|_| panic!("Failed to refresh replica masking triggers for {tablename}"));

    Some(true)
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::label_providers::ANON_DEFAULT_MASKING_POLICY;
    use crate::replica_masking::*;

    #[pg_test]
    fn test_trigger_new_assignments() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_person();
        fixture::enable_replica_masking();
        assert_eq!(
            trigger_new_assignments(relid, "does_not_exits".into()),
            None
        );
        assert_eq!(
            trigger_new_assignments(relid, anon.clone()),
            Some(
                "NEW.\"lastname\" = (SELECT CAST(NULL AS text) FROM (SELECT NEW.* ) AS n);".into()
            )
        );
    }

    #[pg_test]
    fn test_trigger_new_assignments_with_quotes() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_user();
        fixture::enable_replica_masking();
        assert_eq!(
            trigger_new_assignments(relid, anon),
            Some(
                "NEW.\"Email\" = (SELECT CAST(anon.fake_email() AS text) FROM (SELECT NEW.* ) AS n);"
                .into()
            )
        );
    }

    #[pg_test]
    fn test_replica_masking_not_enabled() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_user();
        assert_eq!(Some(false), refresh_replica_trigger_for_table(relid, anon));
    }

    #[pg_test]
    fn test_refresh_replica_trigger_for_table_no_policy() {
        let policy = "does_not_exist".to_string();
        let relid = fixture::create_table_user();
        fixture::enable_replica_masking();
        assert_eq!(None, refresh_replica_trigger_for_table(relid, policy));
    }

    #[pg_test]
    fn test_refresh_replica_trigger_for_table() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_user();
        fixture::enable_replica_masking();
        assert_eq!(Some(true), refresh_replica_trigger_for_table(relid, anon));
    }

    #[pg_test]
    fn test_refresh_replica_trigger_for_table_does_not_exist() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        fixture::enable_replica_masking();
        assert_eq!(
            None,
            refresh_replica_trigger_for_table(pg_sys::InvalidOid, anon)
        );
    }

    #[pg_test]
    fn test_refresh_replica_trigger_for_table_no_rules() {
        let anon = ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_location();
        fixture::enable_replica_masking();
        assert_eq!(None, refresh_replica_trigger_for_table(relid, anon.clone()));
    }
}
