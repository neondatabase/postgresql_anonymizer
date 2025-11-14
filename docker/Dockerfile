
# This instructions must be declared before any FROM
# You can override it and build your own image based another version
# like this: `PG_MAJOR_VERSION=17 make docker_image`
ARG DOCKER_PG_MAJOR_VERSION=17

FROM postgres:$DOCKER_PG_MAJOR_VERSION

# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG DOCKER_PG_MAJOR_VERSION=17

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
 && rm -rf /var/lib/apt/lists/*

# Install anon extension
ARG ANON_VERSION=latest
RUN wget https://gitlab.com/api/v4/projects/7709206/packages/generic/deb/$ANON_VERSION/postgresql_anonymizer_pg$DOCKER_PG_MAJOR_VERSION-$ANON_VERSION.amd64.deb \
 && dpkg -i postgresql_anonymizer_pg$DOCKER_PG_MAJOR_VERSION-$ANON_VERSION.amd64.deb

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_anon.sh /docker-entrypoint-initdb.d/init_anon.sh

# Entrypoint for Anonymized Dumps
COPY docker/dump.sh /dump.sh
