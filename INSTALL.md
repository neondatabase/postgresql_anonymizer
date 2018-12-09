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

