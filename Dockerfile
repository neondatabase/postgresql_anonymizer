FROM postgres:10

RUN mkdir -p '/usr/share/postgresql/10/extension/anon'  
                                                                                                     
COPY anon--0.0.1.sql  /usr/share/postgresql/10/extension/anon
COPY anon.control  /usr/share/postgresql/10/extension/ 
