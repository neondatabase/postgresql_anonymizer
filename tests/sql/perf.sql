CREATE EXTENSION IF NOT EXISTS anon;

--SET search_path TO pg_temp; 

CREATE TABLE customer(
	id SERIAL,
	full_name TEXT
);

INSERT INTO customer(id, full_name)
SELECT generate_series(1,1000), 'X Y';


\timing

-- basic modification
UPDATE customer SET full_name='A B';


UPDATE customer                                                                                                                                        
SET                                                                                                                                                    
    full_name=anon.random_first_name()                                                                              
;      

UPDATE customer                                                                                                                                        
SET                                                                                                                                                    
    full_name=anon.random_last_name()                                                                              
;      

UPDATE customer
SET 
	full_name=anon.random_first_name() || ' ' || anon.random_last_name()
;

\echo 'test4b UNLOGGED'

CREATE UNLOGGED TABLE fake_customer AS 
SELECT 
	id,
	full_name=anon.random_first_name() || ' ' || anon.random_last_name() 
FROM customer
;


