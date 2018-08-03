FROM postgres:10

RUN mkdir -p '/usr/share/postgresql/10/extension/'  
                                                                                                     
COPY anon*  /usr/share/postgresql/10/extension/
