# vim:set ft=dockerfile:
ARG UBI_VERSION=8.5-204
ARG PGBOUNCER_VERSION=1.16.1

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
ARG TARGETARCH

LABEL name="PgBouncer Container Images" \
      vendor="EnterpriseDB" \
      url="https://www.enterprisedb.com/" \
      version="1.16.1" \
      release="6" \
      summary="Container images for PgBouncer (connection pooler for PostgreSQL)." \
      description="This Docker image contains PgBouncer based on RedHat Universal Base Images (UBI) 8 minimal."

COPY root/ /

RUN --mount=type=secret,id=cs_script,target=/run/secrets/cs_script.sh \
        set -xe ; \
        rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm ; \
        ARCH="${TARGETARCH}" ; \
        base_url="https://download.postgresql.org/pub/repos/yum/reporpms" ; \
        case $ARCH in \
            amd64) \
                rpm -i "${base_url}/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm" ;; \
            ppc64le) \
                rpm -i "${base_url}/EL-8-ppc64le/pgdg-redhat-repo-latest.noarch.rpm" ;; \
            arm64) \
                rpm -i "${base_url}/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm" ;; \
            s390x) \
                bash /run/secrets/cs_script.sh ;; \
            *) \
                exit 1 ;; \
        esac ; \
        microdnf -y install libevent openssl udns shadow-utils findutils ; \
        microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs --nodocs --noplugins postgresql13 ; \
        microdnf -y clean all --enablerepo='*' ; \
        rm -fr /etc/yum.repos.d/enterprisedb-edb.repo ; \
        rm -fr /tmp/* ; \
        adduser -r pgbouncer ; \
        mkdir -p /var/log/pgbouncer ; \
        mkdir -p /var/run/pgbouncer ; \
        chown pgbouncer:pgbouncer /var/log/pgbouncer ; \
        chown pgbouncer:pgbouncer /var/run/pgbouncer

COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/pgbouncer", "/usr/bin/"]
COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/etc/pgbouncer.ini", "/etc/pgbouncer/pgbouncer.ini.example"]
COPY --from=build ["/pgbouncer-${PGBOUNCER_VERSION}/etc/userlist.txt", "/etc/pgbouncer/userlist.txt.example"]

RUN touch /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/userlist.txt

# DoD 2.3 - remove setuid/setgid from any binary that not strictly requires it, and before doing that list them on the stdout
RUN find / -not -path "/proc/*" -perm /6000 -type f -exec ls -ld {} \; -exec chmod a-s {} \; || true

EXPOSE 6432
USER pgbouncer

COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
