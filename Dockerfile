FROM postgres:11

RUN apt-get update && apt-get install -y \
  		make \
		postgresql-server-dev-all  \
		wget \
 && rm -rf /var/lib/apt/lists/*

# Install pgddl extension
ENV PGDDL_RELEASE 0.10
ENV PGDDL_URL https://github.com/lacanoid/pgddl/archive/${PGDDL_RELEASE}.tar.gz

RUN mkdir pgddl && \
    wget -O pgddl.tar.gz ${PGDDL_URL} && \
    tar xzvf pgddl.tar.gz && \
    make -C pgddl-${PGDDL_RELEASE} && \
    make -C pgddl-${PGDDL_RELEASE} install

# Install anon extension
COPY anon*  /usr/share/postgresql/11/extension/
