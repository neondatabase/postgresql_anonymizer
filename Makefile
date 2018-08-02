ION = anon       
DATA = anon--0.0.1.sql  
REGRESS = anon_test     

extension: anon/$(DATA)

anon/$(DATA): 
	cat sql/header.sql > $@ 
	cat sql/tables/*.sql >> $@
	cat sql/functions/first_names.sql >> $@


PG_DUMP=docker exec postgresqlanonymizer_PostgreSQL_1 pg_dump -U postgres --insert --no-owner 
SED1=sed 's/public.//' 
SED2=sed 's/SELECT.*search_path.*//' 

sql/tables/%.sql:
	$(PG_DUMP) --table $* | $(SED1) | $(SED2) > $@

PGPASSWORD=CHANGEME 

PSQL=PGPASSWORD=CHANGEME psql -U postgres -h 0.0.0.0 -p54322

docker_init:
	docker-compose down
	docker-compose up -d

SQL_SCRIPTS= load test test_drop

load: data/load.sql
test: tests/anon_test.sql
test_drop: tests/drop.sql

$(SQL_SCRIPTS):
	$(PSQL) -f $^

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
