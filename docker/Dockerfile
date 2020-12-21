ARG PG_MAJOR_VERSION=13

FROM postgres:$PG_MAJOR_VERSION

# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG PG_MAJOR_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    make \
    postgresql-server-dev-$PG_MAJOR_VERSION\
    wget \
 && rm -rf /var/lib/apt/lists/*

# Install anon extension
WORKDIR /src
COPY . .
RUN make clean && make && make install

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_anon.sh /docker-entrypoint-initdb.d/init_anon.sh

# Alternative Entrypoint
COPY docker/anon.sh /anon.sh
