CREATE EXTENSION IF NOT EXISTS anon;

SET search_path TO pg_temp; 

CREATE TABLE customer(
	full_name TEXT,
	birth DATE,
	employer TEXT,
	zipcode TEXT
);

INSERT INTO customer
VALUES 
('Chuck Norris','1940/03/10','Texas Rangers', '75001'),
('David Hasselhoff','1952/07/17','Baywatch', '90001')
;

SELECT * FROM customer;

UPDATE customer
SET 
	full_name=anon.random_first_name() || ' ' || anon.random_last_name(),
	birth=anon.random_date_between('01/01/1920'::DATE,now()),
	employer=anon.random_company(),
	zipcode=anon.random_zip()	
;

SELECT * FROM customer;
