///
/// # Test fixtures
///
/// Create objects for testing purpose
///
/// This is a very basic testing context !
///
/// For more sophisticated use cases, use the `pg_regress` functional test suite
/// See the `make installcheck` target for more details
///
use pgrx::prelude::*;

// dead_code warnings are disabled because this mod is loaded in lib.rs
// in order to make it available to all the others mod test section,
// but `cargo pgrx run` can't see where these functions are used

#[allow(dead_code)]
pub fn create_masking_functions() -> pg_sys::Oid {
    Spi::run("
        CREATE SCHEMA outfit;
        CREATE FUNCTION outfit.mask(SMALLINT) RETURNS SMALLINT LANGUAGE SQL AS $$ SELECT 0::SMALLINT $$;
        CREATE FUNCTION outfit.mask(INT) RETURNS INT LANGUAGE SQL AS $$ SELECT 0 $$;
        CREATE FUNCTION outfit.mask(BIGINT) RETURNS BIGINT LANGUAGE SQL AS $$ SELECT 0::BIGINT $$;
        SECURITY LABEL FOR anon ON FUNCTION outfit.mask(SMALLINT) IS 'TRUSTED';
        SECURITY LABEL FOR anon ON FUNCTION outfit.mask(INT) IS 'TRUSTED';

        CREATE FUNCTION outfit.belt() RETURNS TEXT LANGUAGE SQL AS $$ SELECT 'x' $$;
        CREATE FUNCTION public.belt() RETURNS TEXT LANGUAGE SQL AS $$ SELECT 'x' $$;
        SECURITY LABEL FOR anon ON FUNCTION outfit.belt() IS 'UNTRUSTED';
        SECURITY LABEL FOR anon ON FUNCTION public.belt() IS 'TRUSTED';

        CREATE FUNCTION outfit.cape() RETURNS INT LANGUAGE SQL AS $$ SELECT 0 $$;
    ").unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'outfit'::REGNAMESPACE::OID;")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_masked_role_in_policy(role: &str, policy: &str) -> pg_sys::Oid {
    Spi::run(
        format!(
            "
        CREATE ROLE {role};
        SECURITY LABEL FOR {policy} ON ROLE {role} is 'MASKED';
    "
        )
        .as_str(),
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>(
        format!(
            "
        SELECT '{role}'::REGROLE::OID;
    "
        )
        .as_str(),
    )
    .unwrap()
    .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_masked_role() -> pg_sys::Oid {
    Spi::run(
        "
        CREATE ROLE batman;
        SECURITY LABEL FOR anon ON ROLE batman is 'MASKED';
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'batman'::REGROLE::OID;")
        .unwrap()
        .expect("should be an OID")
}

// An unmasked table
#[allow(dead_code)]
pub fn create_table_call() -> pg_sys::Oid {
    Spi::run(
        "
         CREATE TABLE call AS
         SELECT  '410-719-9009'::TEXT        AS sender,
                 '410-258-4863'::TEXT        AS receiver,
                 '2004-07-08'::DATE          AS day,
                 1035::INT                   AS duration
         ;
         ALTER TABLE call DROP COLUMN duration;
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'call'::REGCLASS::OID")
        .unwrap()
        .expect("should be an OID")
}

// A masked table with quotes
#[allow(dead_code)]
pub fn create_table_user() -> pg_sys::Oid {
    Spi::run(
        "
        CREATE TABLE \"User\"
            AS SELECT
                'foo@bar.com' AS \"Email\",
                'foobar'      AS \"LoGiN\"
        ;
        SECURITY LABEL FOR anon ON COLUMN \"User\".\"Email\"
            IS 'MASKED WITH FUNCTION anon.fake_email()';
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT '\"User\"'::REGCLASS::OID")
        .unwrap()
        .expect("should be an OID")
}

// A masked table with a dropped column
#[allow(dead_code)]
pub fn create_table_person() -> pg_sys::Oid {
    Spi::run(
        "
         CREATE TABLE person AS
         SELECT
            'She/Her'                   AS pronouns,
            'Sarah'::VARCHAR(30)        AS firstname,
            'Connor'::TEXT              AS lastname
         ;

         ALTER TABLE person DROP COLUMN pronouns;

         SECURITY LABEL FOR anon ON COLUMN person.lastname
           IS 'MASKED WITH VALUE NULL';

         SECURITY LABEL FOR anon ON TABLE person
           IS 'TABLESAMPLE BERNOULLI(10)';
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'person'::REGCLASS::OID")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_table_location() -> pg_sys::Oid {
    Spi::run(
        "
         CREATE SCHEMA \"Postal_Info\";
         CREATE TABLE \"Postal_Info\".location AS
         SELECT  '53540'::VARCHAR(5)        AS zipcode,
                 'Gotham'::TEXT             AS city
         ;
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT '\"Postal_Info\".location'::REGCLASS::OID")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_table_with_defaults() -> pg_sys::Oid {
    Spi::connect_mut(|client| {
        client
            .update(
                "
            CREATE TABLE test_defaults (
                id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
                col_with_default TEXT DEFAULT 'default_value',
                col_with_complex_default TIMESTAMP DEFAULT now(),
                col_without_default INTEGER,
                col_generated NUMERIC GENERATED ALWAYS AS (col_without_default / 2.54) STORED,
                col_dropped TEXT DEFAULT NULL
            );
            ALTER TABLE test_defaults DROP COLUMN col_dropped;
        ",
                None,
                &[],
            )
            .unwrap();

        let relid = client
            .select("SELECT 'test_defaults'::REGCLASS::OID", None, &[])
            .unwrap()
            .first()
            .get_one::<pg_sys::Oid>()
            .unwrap();

        relid
    })
    .unwrap()
}

#[allow(dead_code)]
pub fn create_trusted_schema() -> pg_sys::Oid {
    Spi::run(
        "
        CREATE SCHEMA gotham;
        SECURITY LABEL FOR anon ON SCHEMA gotham is 'TRUSTED';
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'gotham'::REGNAMESPACE::OID;")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_unmasked_role() -> pg_sys::Oid {
    Spi::run(
        "
        CREATE ROLE bruce;
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'bruce'::REGROLE::OID;")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn create_untrusted_schema() -> pg_sys::Oid {
    Spi::run(
        "
        CREATE SCHEMA arkham;
    ",
    )
    .unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'arkham'::REGNAMESPACE::OID;")
        .unwrap()
        .expect("should be an OID")
}

#[allow(dead_code)]
pub fn declare_masking_policies() {
    Spi::run(
        "
        SET anon.masking_policies = 'devtests, analytics';
    ",
    )
    .unwrap();
}

#[allow(dead_code)]
pub fn declare_sampling_for_database(db: String) {
    Spi::run(&format!(
        "
        SECURITY LABEL FOR anon ON DATABASE {db}
            IS 'TABLESAMPLE SYSTEM(33)';
    "
    ))
    .unwrap();
}

#[allow(dead_code)]
pub fn trust_masking_functions_schema() {
    Spi::run(
        "
        SECURITY LABEL FOR anon ON SCHEMA outfit IS 'TRUSTED';
    ",
    )
    .unwrap();
}
