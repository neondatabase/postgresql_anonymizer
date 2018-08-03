
--
-- Generic Types
--

CREATE OR REPLACE FUNCTION random_string(l integer)
RETURNS text AS $$ SELECT array_to_string(
			array(
				select substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',((random()*(36-1)+1)::integer),1) 
				from generate_series(1,l)
			),''
		  ); $$           
LANGUAGE SQL; 

-- Zip code 
CREATE OR REPLACE FUNCTION random_zip()                                                                                            
RETURNS text AS $$ SELECT array_to_string(                                                                                                             
            array(                                                                                                                                     
                select substr('0123456789',((random()*(10-1)+1)::integer),1)                                                 
                from generate_series(1,5)                                                                                                              
            ),''                                                                                                                                       
          ); $$                                                                                                                                        
LANGUAGE SQL; 


-- date

CREATE OR REPLACE FUNCTION random_date_between(date_start timestamp WITH TIME ZONE, date_end timestamp WITH TIME ZONE)
RETURNS timestamp WITH TIME ZONE AS $$
    SELECT (random()*(date_end-date_start))::interval+date_start;                                                                          
$$                                                                                                                                                     
LANGUAGE SQL; 

CREATE OR REPLACE FUNCTION random_date()
RETURNS timestamp with time zone AS $$
	SELECT random_date_between('01/01/1900'::TIMESTAMP WITH TIME ZONE,now());
$$
LANGUAGE SQL;

--
-- Personal data : First Name, Last Name, etc.
--

CREATE OR REPLACE FUNCTION random_first_name()
RETURNS TEXT AS $$
	SELECT first_name FROM @extschema@.first_names ORDER BY random() LIMIT 1; 
$$
LANGUAGE SQL;


--
-- Company data : Name, SIRET, IBAN, etc.
--

CREATE OR REPLACE FUNCTION random_company()                                                                                                         
RETURNS TEXT AS $$                                                                                                                                     
    SELECT name FROM @extschema@.companies ORDER BY random() LIMIT 1;                                                                          
$$                                                                                                                                                     
LANGUAGE SQL; 
