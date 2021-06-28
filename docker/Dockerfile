ARG PG_MAJOR_VERSION=13

FROM postgres:$PG_MAJOR_VERSION

# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG PG_MAJOR_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    make \
    postgresql-server-dev-$PG_MAJOR_VERSION \
    libc6-dev \
    wget \
    python3 \
    python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Import source files into the image
WORKDIR /src
COPY . .

# Install faker
RUN pip3 install --no-cache-dir -r python/requirements.txt

# Install anon extension
RUN make clean && make && make install

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_anon.sh /docker-entrypoint-initdb.d/init_anon.sh

# Alternative Entrypoint
COPY docker/anon.sh /anon.sh
