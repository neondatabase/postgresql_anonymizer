FROM postgres:12

RUN apt-get update && apt-get install -y \
  		make \
		postgresql-server-dev-all  \
		pgxnclient \
		wget \
 && rm -rf /var/lib/apt/lists/*

# Install pgddl extension
RUN pgxn install ddlx=0.12.0

# Install anon extension
COPY anon*  /usr/share/postgresql/11/extension/
