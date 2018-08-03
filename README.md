Data Anonymizer Extension for PostgreSQL
===============================================================================


Example
------------------------------------------------------------------------------

```sql
=# CREATE EXTENSION IF NOT EXISTS anon;

=# SELECT * FROM customer;
    full_name     |   birth    |    company    | zipcode                                                                                               
------------------+------------+---------------+---------                                                                                              
 Chuck Norris     | 1940-03-10 | Texas Rangers | 75001                                                                                                 
 David Hasselhoff | 1952-07-17 | Baywatch      | 90001                                                                                                 
                                                                                                                                                       
=# UPDATE customer
-# SET
-#   full_name=anon.random_first_name() || ' ' || anon.random_last_name(),
-#   birth=anon.random_date_between('01/01/1920'::DATE,now()),
-#   company=anon.random_company(),
-#   zipcode=anon.random_zip()
-# ;      
 
=# SELECT * FROM customer;                                                                                                           
     full_name     |   birth    |     company      | zipcode                                                                                           
-------------------+------------+------------------+---------                                                                                          
 michel Duffus     | 1970-03-24 | Body Expressions | 63824                                                                                             
 andromache Tulip  | 1921-03-24 | Dot Darcy        | 73231 
```



