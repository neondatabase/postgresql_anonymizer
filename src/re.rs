///
/// # Regular Expressions
///
///
use core::ffi::CStr;
use regex::Regex;


//----------------------------------------------------------------------------
// Matches
//----------------------------------------------------------------------------

pub fn is_match_indirect_identifier(haystack: &str) -> bool {
    let re = Regex::new(r"(?is)^ *(QUASI|INDIRECT) +IDENTIFIER *$").unwrap();
    re.is_match(haystack)
}

pub fn is_match_masked(haystack: &str) -> bool {
    let re = Regex::new(r"(?is)^ *MASKED *$").unwrap();
    re.is_match(haystack)
}

pub fn is_match_not_masked(haystack: &str) -> bool {
    let re = Regex::new(r"(?is)^ *NOT +MASKED *$").unwrap();
    re.is_match(haystack)
}


pub fn is_match_trusted(haystack: &str) -> bool {
    let re = Regex::new(r"(?is)^ *TRUSTED *$").unwrap();
    re.is_match(haystack)
}

pub fn is_match_untrusted(haystack: &str) -> bool {
    let re = Regex::new(r"(?is)^ *UNTRUSTED *$").unwrap();
    re.is_match(haystack)
}

//----------------------------------------------------------------------------
// Captures
//----------------------------------------------------------------------------
fn capture_first(re: Regex, haystack: &str) -> Option<&str> {
    let caps = re.captures(haystack);
    if let Some(c) = caps {
        return Some(c.get(1).unwrap().as_str());
    }
    None
}

pub fn capture_function(haystack: &str) -> Option<&str> {
    let re = Regex::new(r"(?is)^ *MASKED +WITH +FUNCTION +(.*) *$").unwrap();
    capture_first(re,haystack)
}

pub fn capture_tablesample(haystack: &str) -> Option<&str> {
    let re = Regex::new(r"(?is)^ *TABLESAMPLE +(.*) *$").unwrap();
    capture_first(re,haystack)
}

pub fn capture_value(haystack: &str) -> Option<&str> {
    let re = Regex::new(r"(?is)^ *MASKED +WITH +VALUE +(.*) *$").unwrap();
    capture_first(re,haystack)
}

///
/// This is a naïve replacement for SplitGUCList
///
pub fn capture_guc_list(haystack: &CStr) -> Vec<&str>  {
    let re = Regex::new(r"[^,(?! )]+").unwrap();
    let hay = haystack.to_str().expect("haystack should be valid");
    let mut v: Vec<&str> = vec!();
    for c in re.captures_iter(hay) {
        v.push(c.get(0).unwrap().as_str());
    }
    v
}

#[cfg(test)]
mod tests {
    use c_str_macro::c_str;
    use crate::re::*;

    #[test]
    fn test_capture_function() {
        assert_eq!(
            Some("public.foo($$x$$)"),
            capture_function("masked WITH function public.foo($$x$$)")
        );
        assert_eq!(
            None,
            capture_function("MASKED WITH public.foo($$x$$)")
        );
    }
    #[test]
    fn test_capture_guc_list() {
        assert_eq!(
            vec!["a","b","c"],
            capture_guc_list(c_str!("a,b , c"))
        );
        assert_eq!(capture_guc_list(c_str!("a,,,,,,,,b,c")).len(),3);
        assert_eq!(capture_guc_list(c_str!("abc dkeiij zofk355f")).len(),3);
    }

    #[test]
    fn test_capture_tablesample() {
        assert_eq!(
            Some("SYSTEM(10)"),
            capture_tablesample("TABLESAMPLE SYSTEM(10)")
        );
        assert_eq!(
            Some("sySTEM(10)"),
            capture_tablesample(" tablesample  sySTEM(10)")
        );
        assert_eq!(
            None,
            capture_tablesample("TABLESAMPLE")
        );
        assert_eq!(
            None,
            capture_tablesample("TABLE SAMPLE SYSTEM(10)")
        );
    }

    #[test]
    fn test_capture_value() {
        assert_eq!(
            Some("NULL "),
            capture_value("MASKED  WiTH value NULL ")
        );
    }

    #[test]
    fn test_re_indirect_identifier() {
        assert!(is_match_indirect_identifier("INDIRECT IDENTIFIER"));
        assert!(is_match_indirect_identifier("quasi identifier"));
        assert!(is_match_indirect_identifier(" QuAsI    idenTIFIER  "));
        assert!(!is_match_indirect_identifier("IDENTIFIER"));
        assert!(!is_match_indirect_identifier("quasi-identifier"));
    }

    #[test]
    fn test_regex_masked() {
        assert!(is_match_masked("MASKED"));
        assert!(is_match_masked("  MaSKeD       "));
        assert!(!is_match_masked("MAKSED"));
    }

    #[test]
    fn test_regex_masked_with_function() {
        assert!(capture_function("MASKED WITH FUNCTION public.foo()").is_some());
        assert!(capture_function(" masked  WITH funCTION bar(0,$$y$$) ").is_some());
        assert!(capture_function(" masked  WITH funCTION bar(0,
                                                                    $$y$$) ").is_some());
        assert!(!capture_function("MASKED WITH FUNCTION").is_some());
        assert!(!capture_function("MASKED WITH public.foo()").is_some());
    }

    #[test]
    fn test_regex_masked_with_value() {
        assert!(capture_value("MASKED WITH VALUE $$zero$$").is_some());
        assert!(capture_value(" masked  WITH vaLue  NULL ").is_some());
        assert!(!capture_value("MASKED WITH VALUE").is_some());
        assert!(!capture_value("MASKED WITH 0").is_some());
    }
    #[test]
    fn test_re_not_masked() {
        assert!(is_match_not_masked("NOT MASKED"));
        assert!(is_match_not_masked("NOT    MASKED"));
        assert!(is_match_not_masked("not masked"));
        assert!(is_match_not_masked(" NoT MaSkED "));
        assert!(is_match_not_masked(" NoT MaSkED "));
        assert!(!is_match_not_masked("NOTMASKED"));
    }


    #[test]
    fn test_re_trusted() {
        assert!(is_match_trusted("TRUSTED"));
        assert!(is_match_trusted("     trusted "));
        assert!(!is_match_trusted("TRUSTTED"));
        assert!(!is_match_trusted("UNTRUSTED"));
    }

    #[test]
    fn test_re_untrusted() {
        assert!(is_match_untrusted("UNTRUSTED"));
        assert!(is_match_untrusted("     untrusted "));
        assert!(!is_match_untrusted("UNTRUSTTED"));
        assert!(!is_match_untrusted("TRUSTED"));
    }
}
