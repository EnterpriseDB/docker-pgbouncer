ARG UBI_VERSION=8.7-1054.1675788412

FROM registry.access.redhat.com/ubi8/ubi:${UBI_VERSION}

RUN --mount=type=secret,id=cs_token,target=/run/secrets/cs_token curl -1sLf \
  "https://downloads.enterprisedb.com/$(cat /run/secrets/cs_token)/dev/setup.rpm.sh" | bash && \
  yum install -y edb-pgbouncer118-1.18.0.0-1.rhel8.x86_64

RUN ln -s /usr/edb/pgbouncer1.18/bin/pgbouncer /usr/bin/pgbouncer && \
    mkdir /controller && ln -s /etc/edb/pgbouncer1.18/ /controller/configs

EXPOSE 6432

USER enterprisedb

COPY entrypoint.sh .

ENTRYPOINT [ "./entrypoint.sh" ]
