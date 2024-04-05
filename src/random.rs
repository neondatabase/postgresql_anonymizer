
use fake::Fake;
use fake::faker::chrono::raw::*;
use fake::faker::number::raw::*;
use fake::locales::EN;
use pgrx::Range;
use std::str::FromStr;


//----------------------------------------------------------------------------
// Range Conversions
//----------------------------------------------------------------------------

/// Convert a pgrx::Range<AnyNumeric> into a Rust Range::<f32>
/// /!\ unbounded range are not allowed
fn range_f32(r: Range<pgrx::AnyNumeric>) -> Option<core::ops::Range::<f32>> {
    let s = &r.lower().unwrap();
    let e = &r.upper().unwrap();
    if r.is_infinite() { return None; }
    let s_f32 = f32::try_from((*s.get().unwrap()).clone()).expect("Conversion error");
    let e_f32 = f32::try_from((*e.get().unwrap()).clone()).expect("Conversion error");
    Some(core::ops::Range::<f32> { start: s_f32, end: e_f32 } )
}

/// Convert a pgrx::Range<AnyNumeric> into a Rust Range::<f64>
/// /!\ unbounded range are not allowed
fn range_f64(r: Range<pgrx::AnyNumeric>) -> Option<core::ops::Range::<f64>> {
    let s = &r.lower().unwrap();
    let e = &r.upper().unwrap();
    if r.is_infinite() { return None; }
    let s_f64 = f64::try_from((*s.get().unwrap()).clone()).expect("Conversion error");
    let e_f64 = f64::try_from((*e.get().unwrap()).clone()).expect("Conversion error");
    Some(core::ops::Range::<f64> { start: s_f64, end: e_f64 } )
}

/// Convert a pgrx::Range<i32> into a Rust Range::<usize>
/// /!\ unbounded range are not allowed
fn range_usize(r: Range<i32>) -> Option<core::ops::Range::<usize>> {
    if r.is_infinite() { return None; }
    Some(core::ops::Range::<usize> {
        start: *r.lower()?.get()? as usize,
        end:   *r.upper()?.get()? as usize
    })
}

/// Convert a pgrx::Range<i64> into a Rust Range::<usize>
/// /!\ unbounded range are not allowed
fn range_usize_from_i64(r: Range<i64>) -> Option<core::ops::Range::<usize>> {
    if r.is_infinite() { return None; }
    Some(core::ops::Range::<usize> {
        start: *r.lower()?.get()? as usize,
        end:   *r.upper()?.get()? as usize
    })
}

//----------------------------------------------------------------------------
// Time
//----------------------------------------------------------------------------

// Currently there's no way to simply convert a chrono date into a
// pgrx::datum::Date. So we use the String representation of the date as an
// intermediary format.
// but this may change in the near future
// https://github.com/pgcentralfoundation/pgrx/pull/1603
//


// We can't use `fake::faker::chrono::raw::Date(EN).fake()`
// because fake-rs generates dates with year 0 (e.g. 0000-10-14)
// and Postgres does not accept that
// https://github.com/cksac/fake-rs/issues/177
pub fn date() -> pgrx::datum::TimestampWithTimeZone {
    let day_one = "1900-01-01T00:00:00+00:00";
    let d = chrono::DateTime::parse_from_rfc3339(day_one).unwrap();
    let val: String = DateTimeAfter(EN,d.into()).fake();
    pgrx::datum::TimestampWithTimeZone::from_str(&val).unwrap()
}

pub fn date_after(t: pgrx::datum::TimestampWithTimeZone)
    -> pgrx::datum::TimestampWithTimeZone
{
    use pgrx::ToIsoString;
    let s: String = t.to_iso_string();
    let d = chrono::DateTime::parse_from_rfc3339(&s)
            .expect("DateTime conversion failed");
    let val: String = DateTimeAfter(EN,d.into()).fake();
    pgrx::datum::TimestampWithTimeZone::from_str(&val).unwrap()
}

pub fn date_before(t: pgrx::datum::TimestampWithTimeZone)
    -> pgrx::datum::TimestampWithTimeZone
{
    use pgrx::ToIsoString;
    let s: String = t.to_iso_string();
    let d = chrono::DateTime::parse_from_rfc3339(&s)
            .expect("DateTime conversion failed");
    let val: String = DateTimeBefore(EN,d.into()).fake();
    pgrx::datum::TimestampWithTimeZone::from_str(&val).unwrap()
}


pub fn date_between(
        start: pgrx::datum::TimestampWithTimeZone,
        end: pgrx::datum::TimestampWithTimeZone
    ) -> pgrx::datum::TimestampWithTimeZone
{
    use pgrx::ToIsoString;
    let start_str: String = start.to_iso_string();
    let start_date = chrono::DateTime::parse_from_rfc3339(&start_str)
                     .expect("DateTime conversion failed");
    let end_str: String = end.to_iso_string();
    let end_date = chrono::DateTime::parse_from_rfc3339(&end_str)
                   .expect("DateTime conversion failed");
    let val: String = DateTimeBetween(EN,start_date.into(),end_date.into())
                      .fake();
    pgrx::datum::TimestampWithTimeZone::from_str(&val).unwrap()
}

pub fn date_in_daterange(r: Range<pgrx::Date>) -> Option<pgrx::Date>
{
    if r.is_infinite() { return None }

    let start = r.lower().unwrap();
    let end = r.upper().unwrap();

    Some(date_between(
            (*start.get().unwrap()).into(),
            (*end.get().unwrap()).into()
        ).into()
    )
}

pub fn date_in_tsrange(r: Range<pgrx::Timestamp>) -> Option<pgrx::Timestamp>
{
    if r.is_infinite() { return None }

    let start = r.lower().unwrap();
    let end = r.upper().unwrap();

    Some(date_between(
            (*start.get().unwrap()).into(),
            (*end.get().unwrap()).into()
        ).into()
    )
}

pub fn date_in_tstzrange(r: Range<pgrx::datum::TimestampWithTimeZone>)
    -> Option<pgrx::datum::TimestampWithTimeZone>
{
    if r.is_infinite() { return None }

    let start = r.lower().unwrap();
    let end = r.upper().unwrap();
    Some(date_between(*start.get().unwrap(),*end.get().unwrap()))
}

pub fn time() -> pgrx::datum::Time {
    let val: String = fake::faker::chrono::raw::Time(EN).fake();
    pgrx::datum::Time::from_str(&val).unwrap()
}


//----------------------------------------------------------------------------
// Numbers
//----------------------------------------------------------------------------

pub fn bigint(r: Range<i64>) -> Option<i64> {
    Some(i64::try_from(range_usize_from_i64(r)?.fake::<usize>()).expect("Out of Bound"))
}

pub fn double_precision(r: Range<pgrx::AnyNumeric>) -> Option<f64> {
    Some(range_f64(r)?.fake::<f64>())
}

pub fn int(r: Range<i32>) -> Option<i32> {
    Some(i32::try_from(range_usize(r)?.fake::<usize>()).expect("Out of Bound"))
}

pub fn number_with_format(format: &'static str) -> String {
    NumberWithFormat(EN, format).fake()
}

pub fn numeric(r: Range<pgrx::AnyNumeric>) -> Option<pgrx::AnyNumeric> {
    Some(pgrx::AnyNumeric::try_from(range_f64(r)?.fake::<f64>()).expect("Out of Bound"))
}

pub fn real(r: Range<pgrx::AnyNumeric>) -> Option<f32> {
    Some(range_f32(r)?.fake::<f32>())
}

//----------------------------------------------------------------------------
// Strings
//----------------------------------------------------------------------------


pub fn string(r: Range<i32>) -> Option<String> {
    Some(range_usize(r)?.fake::<String>())
}

//----------------------------------------------------------------------------
// Tests
//----------------------------------------------------------------------------

#[cfg(test)]
mod tests {


    #[test]
    fn test_int() {
        use crate::random::int;
        assert!(int(pgrx::Range::<i32>::new(1, 10)).is_some());
        assert_eq!(int(pgrx::Range::<i32>::new(1, 2)),Some(1));
        assert!(int(pgrx::Range::<i32>::new(None, 10)).is_none());
        assert!(int(pgrx::Range::<i32>::new(1, None)).is_none());
        assert!(int(pgrx::Range::<i32>::new(None, None)).is_none());
    }

    #[test]
    fn test_string() {
        use crate::random::string;
        assert!(string(pgrx::Range::<i32>::new(1, 10)).is_some());
        assert!(string(pgrx::Range::<i32>::new(None, 10)).is_none());
        assert!(string(pgrx::Range::<i32>::new(1, None)).is_none());
        assert!(string(pgrx::Range::<i32>::new(None, None)).is_none());
    }


}
