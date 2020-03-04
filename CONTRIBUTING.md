How To Contribute
===============================================================================

This project is an **experiment**. Any comment or idea is more than welcome.

Here's a few tips to get started if you want to get involved

Where to start ?
------------------------------------------------------------------------------

If you want to help, here's a few ideas :

1- **Testing** : You can install the `master` branch of the project and realize
extensive tests based on your use case. This is very useful to improve the
stability of the code. Eventually if you can publish you test cases, please
add them in the `/tests/sql` directory or in `demo`. I have recently
implemented "anonymous dumps" and I need feedback !

2- **Documentation** : You can write documentation and examples to help new
users. I have created a `docs` folder where you can put documentation on
how to install and use the extension...

3- **Benchmark** : You run tests on various setups and measure the impact of the
extension on performances

4- **Junior Jobs** : I have flagged a few issues as "[Junior Jobs]"  on the project
[issue board]. If you want to give a try, simply fork the git repository
and start coding !

5- **Spread the Word** : If you loke this extension, just let other people know !
You can publish a blog post about it or a youtube video or wahtever format
you feel comfortable with !

In any case, let us know how we can help you moving forward

[Junior Jobs]: https://gitlab.com/dalibo/postgresql_anonymizer/issues?label_name%5B%5D=Junior+Jobs
[issue board]: https://gitlab.com/dalibo/postgresql_anonymizer/issues


Forking, mirroring and Rebasing
-------------------------------------------------------------------------------

To contribute code to this projet, you can simply create you own fork. 

Over time, the main repository ( let's call it `upstream`) will evolve and your 
own repository (let's call it  `origin`) will miss the latest commits. Here's 
a few hints on how to handle this

### Connect your repo to the upstream 

Add a new remote to your local repo:

```bash
git remote add upstream https://gitlab.com/dalibo/postgresql_anonymizer.git 
```

### Keep your master branch up to date

At any time, you can mirror your personal repo like this:

```bash
# switch to the master branch
git checkout master
# download the latest commit from the main repo
git fetch upstream
# apply the latest commits
git rebase upstream/master
# push the changes to your personal repo
git push origin
```

### Rebase a branch

When working on a Merge Requests (`MR`) that takes a long time, it can happen 
that your local branch (let's call it `foo`) is out of sync. Here's how you
can apply the lastest: 


```bash
# switch to your working branch branch
git checkout foo
# download the latest commit from the main repo
git fetch upstream
# apply the latest commits
git rebase upstream/master
# push the changes to your personal repo
git push origin --force-with-lease
```




Adding new functions
-------------------------------------------------------------------------------

The set of funtions is based on my own experience. I tried to cover the most
common personal data types. If you need an addditional function, let me know !



Testing with docker
-------------------------------------------------------------------------------

You can easily set up a proper testing environment from scratch with docker
and docker-compose !

First launch a container with :

```bash
make docker_init
```

Then you can enter inside the container :

```bash
make docker_bash
```

Once inside the container, you can do the classic operations :

```bash
make
make install
make installcheck
psql
```




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
