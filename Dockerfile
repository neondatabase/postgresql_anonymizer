FROM postgres:11

RUN apt-get update && apt-get install -y \
  		make \
		postgresql-server-dev-all  \
 && rm -rf /var/lib/apt/lists/*

COPY anon*  /usr/share/postgresql/10/extension/
