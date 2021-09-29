# vim:set ft=dockerfile:
ARG UBI_VERSION=8.4-210
ARG PGBOUNCER_VERSION=1.16.0

FROM registry.access.redhat.com/ubi8/ubi-minimal:${UBI_VERSION} AS build
ARG PGBOUNCER_VERSION

# Install build dependencies. EPEL repository is required by udns
RUN set -xe ; \
        rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm ; \
        microdnf -y install make libevent libevent-devel pkg-config openssl openssl-devel \
            tar gzip gcc udns udns-devel ; \
	microdnf -y clean all --enablerepo='*' ; \
        curl -sL http://www.pgbouncer.org/downloads/files/${PGBOUNCER_VERSION}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz > pgbouncer.tar.gz ; \
        tar xzf pgbouncer.tar.gz ; \
        cd pgbouncer-${PGBOUNCER_VERSION} ; \
        ./configure --without-cares --with-udns ; \
        make
        
FROM registry.access.redhat.com/ubi8/ubi-minimal:${UBI_VERSION}
ARG PGBOUNCER_VERSION

RUN set -xe ; \
        rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm ; \
        microdnf -y install libevent openssl udns shadow-utils ; \
	microdnf -y clean all --enablerepo='*' ; \
        adduser -r pgbouncer ; \
        mkdir -p /var/log/pgbouncer ; \
        mkdir -p /var/run/pgbouncer ; \
        chown pgbouncer:pgbouncer /var/log/pgbouncer ; \
        chown pgbouncer:pgbouncer /var/run/pgbouncer

COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/pgbouncer", "/usr/bin/"]
COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/etc/pgbouncer.ini", "/etc/pgbouncer/pgbouncer.ini.example"]
COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/etc/userlist.txt", "/etc/pgbouncer/userlist.txt.example"]

RUN touch /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/userlist.txt
  
EXPOSE 6432
USER pgbouncer

COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]

