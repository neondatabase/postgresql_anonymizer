FROM postgres:12

RUN apt-get update && apt-get install -y \
    gcc \
    make \
    postgresql-server-dev-12  \
    pgxnclient \
    wget \
 && rm -rf /var/lib/apt/lists/*

# Install pgddl extension
RUN pgxn install ddlx

# Install anon extension
WORKDIR /src
COPY . .
RUN make clean && make && make install

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_anon.sh /docker-entrypoint-initdb.d/init_anon.sh

# Alternative Entrypoint
COPY docker/anon.sh /anon.sh
