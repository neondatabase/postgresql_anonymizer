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
