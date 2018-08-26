EXTENSION = anon
VERSION=0.0.1
DATA = anon/anon--0.0.1.sql
REGRESS=unit
MODULEDIR=extension/anon
REGRESS_OPTS = --inputdir=tests

extension: $(DATA)

$(DATA):
	mkdir -p `dirname $(DATA)`
	cat sql/header.sql > $@
	cat sql/tables/*.sql >> $@
	cat sql/functions.sql >> $@


PG_DUMP?=docker exec postgresqlanonymizer_PostgreSQL_1 pg_dump -U postgres --insert --no-owner
SED1=sed 's/public.//'
SED2=sed 's/SELECT.*search_path.*//'
SED3=sed 's/^SET idle_in_transaction_session_timeout.*//'
SED4=sed 's/^SET row_security.*//'

sql/tables/%.sql:
	$(PG_DUMP) --table $* | $(SED1) | $(SED2) | $(SED3) | $(SED4) > $@


PSQL?=PGPASSWORD=CHANGEME psql -U postgres -h 0.0.0.0 -p54322
PGRGRSS=docker exec postgresqlanonymizer_PostgreSQL_1 /usr/lib/postgresql/10/lib/pgxs/src/test/regress/pg_regress --outputdir=tests/ --inputdir=./ --bindir='/usr/lib/postgresql/10/bin'  --inputdir=tests --dbname=contrib_regression --user=postgres unit

##
## Docker
##

docker_image: Dockerfile
	docker build -t registry.gitlab.com/daamien/postgresql_anonymizer .

docker_push:
	docker push registry.gitlab.com/daamien/postgresql_anonymizer

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
## Load data from CSV files into SQL tables
##

.PHONY: load
load:
	$(PSQL) -f data/load.sql

##
## Tests
##
test_unit: tests/sql/unit.sql
test_demo: tests/sql/demo.sql
test_create: tests/sql/create.sql
test_drop: tests/sql/drop.sql

tests/sql/%.sql:
	$(PSQL)	-f $@


##
## CI
##

ci_local:
	gitlab-ci-multi-runner exec docker make

##
## PGXN
##

ZIPBALL:=$(EXTENSION)-$(VERSION).zip

.PHONY: pgxn

$(ZIPBALL): pgxn

pgxn:
	mkdir -p _pgxn
	git archive --format zip --prefix=$(EXTENSION)_$(VERSION)/ --output _pgxn/$(ZIPBALL) master

##
## Mandatory PGXS stuff
##
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

