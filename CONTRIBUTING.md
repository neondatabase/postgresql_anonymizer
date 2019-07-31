How To Contribute
===============================================================================

This project is an **experiment**. Any comment or idea is more than welcome.

Here's a few tips to get started if you want to get involved


Adding new functions
-------------------------------------------------------------------------------

The set of funtions is based on my own experience. I tried to cover the most
common personal data types. If you need an addditional function, let me know !



Testing with docker
-------------------------------------------------------------------------------

You can easily set up a proper testing environment from scratch with docker
and docker-compose !

First launch a container with :

```console
make docker_init
```

Then you can enter inside the container :

```console
make docker_bash
```

Once inside the container, you can do the classic operations :

```console
make
make install
make installcheck
psql
```

Publishing a new Release
-------------------------------------------------------------------------------

☑️ Check that the CI jobs runs without errors on the `master` branch

☑️ Close all remaining issues on the current milestone

☑️ Update the [Changelog](CHANGELOG.md)

☑️ Write the [announcement](NEWS.md)

☑️ Upload the zipball to PGXN

☑️ Check the PGXN install process

☑️ Publish the announcement

☑️ Close the current milsetone and open the next one

☑️ Bump to the new version number in [anon.control]() and [META.json]()


About SQL Injection
--------------------------------------------------------------------------------

By design, this extension is prone to SQL Injections risks. When adding new
features, a special focus should be made on security, especially by sanitizing 
the functions parameters and using `regclass` and `oid` instead of literal 
names to designate objects...

See links below for more details:

* https://stackoverflow.com/questions/10705616/table-name-as-a-postgresql-function-parameter
* https://www.postgresql.org/docs/current/datatype-oid.html
* https://xkcd.com/327/