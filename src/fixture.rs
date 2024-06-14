///
/// # Test fixtures
///
/// Create objects for testing purpose
///
/// This is a very basic testing context !
///
/// For more sophisticated use cases, use the `pg_regress` functional test suite
/// See the `make installcheck` target for more details

use pgrx::prelude::*;

pub fn create_masked_role() -> pg_sys::Oid {
    Spi::run("
        CREATE ROLE batman;
        SECURITY LABEL FOR anon ON ROLE batman is 'MASKED';
    ").unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'batman'::REGROLE::OID;")
        .unwrap()
        .expect("should be an OID")
}

pub fn create_table_person() -> pg_sys::Oid {
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

pub fn create_trusted_schema() -> pg_sys::Oid {
    Spi::run("
        CREATE SCHEMA gotham;
        SECURITY LABEL FOR anon ON SCHEMA gotham is 'TRUSTED';
    ").unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'gotham'::REGNAMESPACE::OID;")
        .unwrap()
        .expect("should be an OID")
}

pub fn create_unmasked_role() -> pg_sys::Oid {
    Spi::run("
        CREATE ROLE bruce;
    ").unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'bruce'::REGROLE::OID;")
        .unwrap()
        .expect("should be an OID")
}

pub fn create_untrusted_schema() -> pg_sys::Oid {
    Spi::run("
        CREATE SCHEMA arkham;
    ").unwrap();
    Spi::get_one::<pg_sys::Oid>("SELECT 'arkham'::REGNAMESPACE::OID;")
        .unwrap()
        .expect("should be an OID")
}