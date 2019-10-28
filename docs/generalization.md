Generalization
===============================================================================


Reducing the accuracy of sensible data
--------------------------------------------------------------------------------

TODO

Exemple
--------------------------------------------------------------------------------

TODO

Generalization Functions
--------------------------------------------------------------------------------

TODO

Limitation
--------------------------------------------------------------------------------

### Singling out and extreme values

TODO 

### Generalization is not compatible with dynamic masking

TODO 


K-Anonymity
--------------------------------------------------------------------------------

```sql
SECURITY LABEL FOR anon ON COLUMN patient.firstname IS 'INDIRECT IDENTIFIER';
SECURITY LABEL FOR anon ON COLUMN patient.zipcode IS 'INDIRECT IDENTIFIER';
SECURITY LABEL FOR anon ON COLUMN patient.birth IS 'INDIRECT IDENTIFIER';
```

```sql
SELECT anon.k_anonymity('patient')
```

TODO 


Links
--------------------------------------------------------------------------------

TODO
