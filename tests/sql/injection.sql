CREATE EXTENSION IF NOT EXISTS anon CASCADE;

CREATE TABLE a (
    i SERIAL,
    d TIMESTAMP,
    x INTEGER
);

--SELECT anon.random_phone('11; SELECT 0;') LIKE '11; SELECT 0;%'

--SELECT anon.add_noise_on_numeric_column('a; SELECT 1','x',0.5);
--SELECT anon.add_noise_on_numeric_column('a','x; SELECT 1',0.5);

--SELECT anon.add_noise_on_datetime_column('a; SELECT 1','d','2 days');
--SELECT anon.add_noise_on_datetime_column('a','d; SELECT 1','2 days');
--SELECT anon.add_noise_on_datetime_column('a','d','2 days; SELECT 1');

SELECT anon.shuffle_column('a; SELECT 1','x','i');
SELECT anon.shuffle_column('a','x; SELECT 1','i');
SELECT anon.shuffle_column('a','x','i; SELECT 1');

--SELECT anon.load('/dev/null''; CREATE TABLE inject (i int);--');

DROP TABLE a;
DROP EXTENSION anon CASCADE;
