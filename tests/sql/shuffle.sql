CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- 
CREATE TABLE test_shuffle (
	id SERIAL,
	key   TEXT,
	value  INT
);

INSERT INTO test_shuffle
VALUES 
	( 1, 'a', 40 ),
	( 2, 'b', 70 ),
    ( 3, 'c', 12 ),
    ( 4, 'd', 33 ),
    ( 5, 'e', 71 ),
    ( 6, 'f', 21 ),
    ( 7, 'g', 29 ),
    ( 8, 'h', 22 ),
    ( 9, 'i', 27 ),
    ( 10, 'j', 51 )
;

CREATE TABLE test_shuffle_backup 
AS SELECT * FROM test_shuffle;

SELECT suffle('test_shuffle','value');

-- TEST 1 : partial 

SELECT sum(a.value) = sum(b.value) 
FROM 
	test_shuffle a,
	test_shuffle_backup b
;

SELECT avg(a.value) = avg(b.value) 
FROM 
    test_shuffle a,
    test_shuffle_backup b
;


DROP EXTENSION anon;
