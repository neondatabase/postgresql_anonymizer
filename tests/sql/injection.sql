CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Sample Table
CREATE TABLE a (
    i SERIAL,
    d TIMESTAMP,
    x INTEGER
);


-- random_phone
SELECT anon.random_phone('11; SELECT 0;') LIKE '11; SELECT 0;%';

-- add_noise_on_numeric_column
SELECT anon.add_noise_on_numeric_column('a; SELECT 1','x',0.5);
SELECT anon.add_noise_on_numeric_column('a','x; SELECT 1',0.5);

-- add_noise_on_datetime_column
SELECT anon.add_noise_on_datetime_column('a; SELECT 1','d','2 days');
SELECT anon.add_noise_on_datetime_column('a','d; SELECT 1','2 days');
SELECT anon.add_noise_on_datetime_column('a','d','2 days; SELECT 1');

-- shuffle_column
SELECT anon.shuffle_column('a; SELECT 1','x','i');
SELECT anon.shuffle_column('a','x; SELECT 1','i');
SELECT anon.shuffle_column('a','x','i; SELECT 1');

-- load
SELECT anon.load('/dev/null''; CREATE TABLE inject (i int);--');

-- mask_init
SELECT anon.mask_init('public','foo; CREATE TABLE inject (i int);--');

-- CLEAN UP
DROP TABLE a;
DROP EXTENSION anon CASCADE;
