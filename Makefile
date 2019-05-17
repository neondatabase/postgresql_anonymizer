###############################################################################
#
# Makefile 
#
###############################################################################

##
## V A R I A B L E S
##

# This Makefile has many input variables, 
# see link below for the standard vars offered by PGXS
# https://www.postgresql.org/docs/current/extend-pgxs.html

# The input variable below are optional

# PSQL : psql client ( default = local psql )
# PGDUMP : pg_dump tool  ( default = docker )
# PG_TEST_EXTRA : extra tests to be run by `installcheck` ( default = none )

##
## C O N F I G
##

EXTENSION = anon
EXTENSION_VERSION=$(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")
DATA = anon/*
# Use this var to add more tests
#PG_TEST_EXTRA ?= ""
REGRESS = load noise shuffle random faking partial masking
REGRESS+=$(PG_TEST_EXTRA)
MODULEDIR=extension/anon
REGRESS_OPTS = --inputdir=tests

##
## B U I L D
##

.PHONY: extension
extension: anon/ anon/anon--$(EXTENSION_VERSION).sql anon/anon.no_extension.sql

anon/:
	mkdir -p anon 
	cp data/default/* anon/

anon/anon--$(EXTENSION_VERSION).sql: anon.sql
	cp anon.sql anon/anon--$(EXTENSION_VERSION).sql

SED1=sed 's/@extschema@/anon/'
SED2=sed 's/.*SELECT pg_catalog.pg_extension_config_dump.*//'
SED3=sed 's/--\$.*//'
SED4=sed 's/--\^ //'
anon/anon.no_extension.sql: anon.sql
	cat $^ | $(SED1) | $(SED2) | $(SED3) | $(SED4) > $@

PG_DUMP?=docker exec postgresqlanonymizer_PostgreSQL_1 pg_dump -U postgres --insert --no-owner 
SED11=sed 's/public.//' 
SED12=sed 's/SELECT.*search_path.*//' 
SED13=sed 's/^SET idle_in_transaction_session_timeout.*//'
SED14=sed 's/^SET row_security.*//'

sql/tables/%.sql:
	$(PG_DUMP) --table $* | $(SED11) | $(SED12) | $(SED13) | $(SED14) > $@


PSQL?=PGPASSWORD=CHANGEME psql -U postgres -h 0.0.0.0 -p54322
PGRGRSS=docker exec postgresqlanonymizer_PostgreSQL_1 /usr/lib/postgresql/10/lib/pgxs/src/test/regress/pg_regress --outputdir=tests/ --inputdir=./ --bindir='/usr/lib/postgresql/10/bin'  --inputdir=tests --dbname=contrib_regression --user=postgres unit

##
## D O C K E R
##

docker_image: Dockerfile
	docker build -t registry.gitlab.com/daamien/postgresql_anonymizer .

docker_push:
	docker push registry.gitlab.com/daamien/postgresql_anonymizer

docker_bash:
	docker exec -it postgresqlanonymizer_PostgreSQL_1 bash

COMPOSE=docker-compose

docker_init:
	$(COMPOSE) down
	$(COMPOSE) up -d
	@echo "The Postgres server may take a few seconds to start. Please wait."


.PHONY: expected
expected : tests/expected/unit.out

tests/expected/unit.out:
	$(PGRGRSS)
	cp tests/results/unit.out tests/expected/unit.out

##
## L O A D
##

.PHONY: load

# Load data from CSV files into SQL tables
load:
	$(PSQL) -f data/load.sql

##
## D E M O   &   T E S T S
##

.PHONY: demo_masking demo_perf demo_random demo_partial
demo_masking: demo/masking.sql
demo_perf: demo/perf.sql
demo_random: demo/random.sql
demo_partial: demo/partial.sql

demo/%.sql:
	$(PSQL) -c 'CREATE DATABASE demo;'
	$(PSQL) --echo-all demo -f $@
	$(PSQL) -c 'DROP DATABASE demo;'

tests/sql/%.sql:
	$(PSQL)	-f $@


##
## C I
##

.PHONY: ci_local
ci_local:
	gitlab-ci-multi-runner exec docker make

##
## P G X N
##

ZIPBALL:=$(EXTENSION)-$(EXTENSION_VERSION).zip

.PHONY: pgxn

$(ZIPBALL): pgxn

pgxn:
	# required by CI : https://gitlab.com/gitlab-com/support-forum/issues/1351
	git clone --bare https://gitlab.com/dalibo/postgresql_anonymizer.git
	git -C postgresql_anonymizer.git archive --format zip --prefix=$(EXTENSION)_$(EXTENSION_VERSION)/ --output ../$(ZIPBALL) master
	# open the package	
	unzip $(ZIPBALL)
	# remove the zipball because we will rebuild it from scratch
	rm -fr $(ZIPBALL)
	# copy artefact into the package
	cp -pr anon ./$(EXTENSION)_$(EXTENSION_VERSION)/
	# remove files that are useless in the PGXN package 
	rm ./$(EXTENSION)_$(EXTENSION_VERSION)/*.gif ./$(EXTENSION)_$(EXTENSION_VERSION)/Dockerfile*
	# rebuild the package
	zip -r $(ZIPBALL) ./$(EXTENSION)_$(EXTENSION_VERSION)/
	# clean up
	rm -fr ./$(EXTENSION)_$(EXTENSION_VERSION) ./postgresql_anonymizer.git/


##
## Mandatory PGXS stuff
##
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
