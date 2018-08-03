CREATE EXTENSION IF NOT EXISTS anon;


CREATE TABLE pg_temp.customer(
	full_name TEXT,
	birth DATE,
	company TEXT,
	zipcode TEXT
);

INSERT INTO pg_temp.customer
VALUES 
('Chuck Norris','1940/03/10','Texas Rangers', '75001'),
('David Hasselhoff','1952/07/17','Baywatch', '90001')
;

SELECT * FROM pg_temp.customer;

UPDATE pg_temp.customer
SET 
	full_name=anon.random_first_name() || ' ' || anon.random_last_name(),
	birth=anon.random_date_between('01/01/1920'::DATE,now()),
	company=anon.random_company(),
	zipcode=anon.random_zip()	
;

SELECT * FROM pg_temp.customer;
