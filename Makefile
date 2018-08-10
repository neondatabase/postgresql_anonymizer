EXTENSION = anon       
DATA = anon/anon--0.0.1.sql  
#REGRESS = tests/unit     
REGRESS=unit
MODULEDIR=extension/anon
#TESTS        = $(wildcard test/sql/*.sql)
#REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=tests

extension: $(DATA)

$(DATA): 
	mkdir -p `dirname $(DATA)`
	cat sql/header.sql > $@ 
	cat sql/tables/*.sql >> $@
	cat sql/functions.sql >> $@


PG_DUMP=docker exec postgresqlanonymizer_PostgreSQL_1 pg_dump -U postgres --insert --no-owner 
SED1=sed 's/public.//' 
SED2=sed 's/SELECT.*search_path.*//' 

sql/tables/%.sql:
	$(PG_DUMP) --table $* | $(SED1) | $(SED2) > $@


PSQL?=PGPASSWORD=CHANGEME psql -U postgres -h 0.0.0.0 -p54322

docker_image: Dockerfile
	docker build -t registry.gitlab.com/daamien/postgresql_anonymizer .

docker_push:
	docker push registry.gitlab.com/daamien/postgresql_anonymizer

docker_init:
	docker-compose down
	docker-compose up -d

SQL_SCRIPTS= load test demo drop perf

load: data/load.sql
test: tests/sql/unit.sql
demo: tests/sql/demo.sql
drop: tests/sql/drop.sql
perf: tests/sql/perf.sql


expected: tests/expected/unit.out

tests/expected/unit.out: tests/sql/unit.sql
	$(PSQL) -f $^ > $@		

$(SQL_SCRIPTS):
	$(PSQL) -f $^

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
