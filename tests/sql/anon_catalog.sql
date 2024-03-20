BEGIN;

CREATE EXTENSION IF NOT EXISTS anon CASCADE;

SELECT anon.version();

SELECT anon.concat('foo', 'bar') = 'foobar';

SELECT anon.date_add('2020-03-19 12:00:00-00:00'::timestamp, '1 week') = '2020-03-26 12:00:00-00:00'::timestamp;

SELECT anon.date_part('day', '2020-03-19 12:00:00-00:00'::timestamp) = 19;

SELECT anon.date_subtract('2020-03-19 12:00:00-00:00'::timestamp, '1 week') = '2020-03-12 12:00:00-00:00'::timestamp;

SELECT anon.date_trunc('month', '2020-03-19 12:00:00-00:00'::timestamp) = '2020-03-01 00:00:00-00:00'::timestamp;

SELECT anon.left('foo', 2) = 'fo';

SELECT anon.length('foo') = 3;

SELECT anon.lower('fOO bAr BAz 123') = 'foo bar baz 123';

SELECT anon.make_date(2020, 3, 19) = '2020-03-19'::date;

SELECT anon.make_time(12, 31, 35.08) = '12:31:35.08'::time;

SELECT anon.md5('foo') = 'acbd18db4cc2f85cedef654fccc4a4d8';

SELECT anon.right('foo', 2) = 'oo';

SELECT anon.substr('foo', 1) = 'oo';

SELECT anon.substr('bazel', 1, 2) = 'az';

SELECT anon.upper('fOO bAr BAz 123') = 'FOO BAR BAZ 123';


ROLLBACK;
