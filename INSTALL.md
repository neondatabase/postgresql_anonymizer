INSTALL
===============================================================================

Install With [PGXN](https://pgxn.org/) :
------------------------------------------------------------------------------

```console
sudo apt install pgxnclient (or pip install pgxn)
sudo pgxn install postgresql_anonymizer
```

Install From source
------------------------------------------------------------------------------

First you need to install the postgresql development libraries. On most
distribution, this is available through a package called `postgresql-devel`
or `postgresql-server-dev`.

Then build the project like any other PostgreSQL extension:

```console
make extension
sudo make install
```

Install in the cloud
------------------------------------------------------------------------------

The main Database As Service operators ( such as Amazon RDS ) do not allow their 
clients to load any extension. Instead they support only a limited subset of 
extensions, such as PostGIS or pgcrypto. You can ask them if they plan to support 
this one in the near future, but I wouldn't bet my life on it 😃

However this tool is set of plpgsql functions, which means should you be able to 
install it directly without declaring an extension.

Here's a few steps to try it out:

```console
$ wget https://gitlab.com/dalibo/postgresql_anonymizer/-/archive/master/postgresql_anonymizer-master.tar
$ tar xvf postgresql_anonymizer-master.tar
$ psql ..... -f anon/anon.no_extension.sql
```

Then you need to load manually the fake datasets with `psql`, like this :

```sql
\copy anon.city FROM 'anon/cities.csv' (FORMAT csv, HEADER, DELIMITER ',');
```

And the activate the masking engine with autoload disabled :

```sql
SELECT anon.mask_init( autoload := FALSE );
```


**However** if privacy and anonymity is a concern to you, hosting your data on 
someone's computer is probably not a clever idea. But then again, what do I
know...









