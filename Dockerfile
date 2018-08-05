FROM postgres:10

RUN apt-get update && apt-get install -y \
  		make \
		postgresql-server-dev-all  \
 && rm -rf /var/lib/apt/lists/*

#RUN mkdir -p '/usr/share/postgresql/10/extension/'  
                                                                                                     
COPY anon*  /usr/share/postgresql/10/extension/
