///
/// # Static Masking
///

use crate::log;
use crate::masking;
use crate::sampling;
use crate::utils;
use pgrx::prelude::*;


/// Return the SQL assignment which will mask the data in a column
/// or null when no masking rule was found
///
fn column_assignment(
    relid: pg_sys::Oid,
    colname: String,
    policy: String
  ) -> Option<String>
{
    let colnum = utils::get_column_number(relid,&colname)?;
    let (masking_filter, att_is_masked) =
        masking::masking_value_for_column(relid,colnum.into(),policy)?;

    if ! att_is_masked { return None; }

    Some(format!("{:?} = {}", colname, masking_filter))
}

/// Return the SQL assignments which will mask the data in a table
///
fn table_assignments(
    relid: pg_sys::Oid,
    policy: String
) ->  Option<String>  {
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

    let mut assignments = Vec::new();
    for a in attrs {
        if a.attisdropped {
            continue;
        }

        let (filter_value, att_is_masked) =
            masking::value_for_att(&relation, a, policy.clone());

        if att_is_masked {
            let attname_quoted = utils::quote_name_data(&a.attname);
            assignments.push(
                format!("{:?} = {}",attname_quoted,filter_value)
            );
        }
    }

    // pass the relation back to Postgres
    unsafe {
        pg_sys::relation_close(relation.as_ptr(), lockmode);
    }

    if assignments.is_empty() { return None ; }
    Some(assignments.join(", ").to_string())
}

/// Apply a masking policy to a column
pub fn anonymize_column(
  relid: pg_sys::Oid,
  colname: String,
  policy: String
) -> Option<bool>
{
    let ratio = sampling::get_ratio(relid,&policy);

    // We can't apply a tablesample rules to just a column
    if ratio.is_ok() {
        notice!(
            "The TABLESAMPLE rule will be ignored.
            Only anonymize_table() and anonymize_database() can apply sampling rules"
        );
    }

    let tablename = utils::get_relation_qualified_name(relid)?;

    let Some(assign) =
        column_assignment(relid, colname.clone(), policy)
        else {
            warning!("There is no masking rule for column {:?} in table {}",
                     colname.clone(),
                     tablename);
            return Some(false);
        };


    let sql = format!("
        SET CONSTRAINTS ALL DEFERRED;
        UPDATE {tablename} SET {assign};
    ");
    log::debug1!("Anon: {sql}");

    Spi::run(&sql).expect("Failed to anonymize column");

    Some(true)
}

/// Apply a masking policy to a relation
pub fn anonymize_table(
  relid: pg_sys::Oid,
  policy: String
) -> Option<bool>
{
    let p=policy.clone();
    let ratio = sampling::get_ratio(relid,&p);
    let tablename = utils::get_relation_qualified_name(relid)?;

    let sql: String = if ratio.is_ok() {
        // If there's a tablesample ratio then we can't simply update the table.
        // we have to rewrite it completely.
        //
        // /!\ If the table has a foreign key, this will likely fail
        //
        let Some(masking_subquery) = masking::subquery(relid,policy)
                                     else { return Some(false); };
        let relint: u32 = relid.into();

        use fake::{Fake, Faker};
        let swap_table = format!("anon_swap_{relint}_{}", Faker.fake::<u32>());

        format!("
            CREATE TEMPORARY TABLE {swap_table}
                AS {masking_subquery};
            TRUNCATE TABLE {tablename};
            INSERT INTO {tablename} SELECT * FROM {swap_table};
            DROP TABLE {swap_table};
        ")
    } else {
        // For compatibility with version 1, instead of returning `Some(false)`
        // we return None/NULL when no rule is found for the table
        //
        let masking_assignments = table_assignments(relid,policy)?;
        format!("UPDATE {tablename} SET {masking_assignments}")
    };

    log::debug1!("Anon: {sql}");
    Spi::run(&sql).expect("Failed to anonymize table");

    Some(true)
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use crate::fixture;
    use crate::static_masking::*;
    use crate::label_providers::ANON_DEFAULT_MASKING_POLICY;

    #[pg_test]
    fn test_column_assignment(){
        let anon=ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_person();
        assert_eq!(
            None,
            column_assignment(relid,"firstname".to_string(),anon.clone())
        );
        assert_eq!(
            Some("\"lastname\" = CAST(NULL AS text)".to_string()),
            column_assignment(relid,"lastname".to_string(),anon.clone())
        );
    }

    #[pg_test]
    fn test_anonymize_column(){
        let anon=ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_person();
        assert_eq!(
            Some(false),
            anonymize_column(relid,"firstname".to_string(),anon.clone())
        );
        assert_eq!(
            Some(true),
            anonymize_column(relid,"lastname".to_string(),anon.clone())
        );
    }

    #[pg_test]
    fn test_anonymize_column_no_policy(){
        let policy="does_not_exist".to_string();
        let relid = fixture::create_table_person();
        assert_eq!(
            Some(false),
            anonymize_column(relid,"firstname".to_string(),policy.clone())
        );
        assert_eq!(
            Some(false),
            anonymize_column(relid,"lastname".to_string(),policy.clone())
        );
    }

    #[pg_test]
    fn test_anonymize_column_does_not_exist(){
        let anon=ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_person();
        assert_eq!(
            Some(false),
            anonymize_column(relid,"does_not_exists".to_string(),anon.clone())
        );
        assert_eq!(
            Some(false),
            anonymize_column(relid,"".to_string(),anon.clone())
        );
    }

    #[pg_test]
    fn test_anonymize_column_invalid_oid(){
        assert_eq!(
            None,
            anonymize_column(pg_sys::InvalidOid,"".to_string(),"anon".to_string())
        );
    }


    #[pg_test]
    fn test_anonymize_table(){
        let anon=ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_person();
        assert_eq!(
            Some(true),
            anonymize_table(relid,anon.clone())
        );
    }


    #[pg_test]
    fn test_anonymize_table_does_not_exist(){
        assert_eq!(
            None,
            anonymize_table(pg_sys::InvalidOid,"anon".to_string())
        );
    }

    #[pg_test]
    fn test_anonymize_table_no_policy(){
        let relid = fixture::create_table_person();
        assert_eq!(
            None,
            anonymize_table(relid,"does_not_exist".to_string())
        );
    }

    #[pg_test]
    fn test_anonymize_table_no_rules(){
        let anon=ANON_DEFAULT_MASKING_POLICY.to_string();
        let relid = fixture::create_table_location();
        assert_eq!(
            None,
            anonymize_table(relid,anon.clone())
        );
    }

}
