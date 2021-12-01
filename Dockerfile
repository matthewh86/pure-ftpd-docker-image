# https://hub.docker.com/_/alpine
FROM alpine:3.15

ARG pure_ftpd_ver=1.0.50
ARG s6_overlay_ver=2.2.0.3
ARG build_rev=0

LABEL org.opencontainers.image.source="\
    https://github.com/instrumentisto/pure-ftpd-docker-image"


# Build and install Pure-FTPd
RUN apk update \
 && apk upgrade \
 && apk add --no-cache \
        ca-certificates \
 && update-ca-certificates \
    \
 # Install Pure-FTPd dependencies
 && apk add --no-cache \
        libretls \
        libsodium \
    \
 # Install tools for building
 && apk add --no-cache --virtual .tool-deps \
        curl coreutils autoconf g++ libtool make \
    \
 # Install Pure-FTPd build dependencies
 && apk add --no-cache --virtual .build-deps \
        libretls-dev \
        libsodium-dev \
    \
 # Download and prepare Pure-FTPd sources
 && curl -fL -o /tmp/pure-ftpd.tar.gz \
         https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-${pure_ftpd_ver}.tar.gz \
 && (echo "d790253fe82a3d83534afd80f5ac9a6995ef4e89f5226cede273f944acc97dccf0275d62f1d5bd056130ed4613f5704ee2746cd6357581e45ea2d730f254afac  /tmp/pure-ftpd.tar.gz" \
         | sha512sum -c -) \
 && tar -xzf /tmp/pure-ftpd.tar.gz -C /tmp/ \
 && cd /tmp/pure-ftpd-* \
    \
 # Build Pure-FTPd from sources
 && ./configure --prefix=/usr \
        --with-puredb \
        --with-quotas \
        --with-ratios \
        --with-rfc2640 \
        --with-throttling  \
        --with-tls \
        --without-capabilities \
        --without-humor \
        --without-inetd \
        --without-usernames \
 && make \
    \
 # Create Pure-FTPd user and groups
 && addgroup -S -g 91 pure-ftpd \
 && adduser -S -u 90 -D -s /sbin/nologin \
            -H -h /data \
            -G pure-ftpd -g pure-ftpd \
            pure-ftpd \
    \
 # Install and configure Pure-FTPd
 && make install \
 && install -d -o pure-ftpd -g pure-ftpd /data \
 # Disable daemonization
 && sed -i -e 's,^Daemonize .*,Daemonize no,' \
        /etc/pure-ftpd.conf \
 # No documentation included to keep image size smaller
 && rm -rf /usr/share/man/* \
    \
 # Cleanup unnecessary stuff
 && apk del .tool-deps .build-deps \
 && rm -rf /var/cache/apk/* \
           /tmp/*


# Install s6-overlay
RUN apk add --update --no-cache --virtual .tool-deps \
        curl \
 && curl -fL -o /tmp/s6-overlay.tar.gz \
         https://github.com/just-containers/s6-overlay/releases/download/v${s6_overlay_ver}/s6-overlay-amd64.tar.gz \
 && tar -xzf /tmp/s6-overlay.tar.gz -C / \
    \
 # Cleanup unnecessary stuff
 && apk del .tool-deps \
 && rm -rf /var/cache/apk/* \
           /tmp/*

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES=1


COPY rootfs /

RUN chmod +x /etc/services.d/*/run \
             /etc/cont-init.d/*


EXPOSE 21 30000-30009

ENTRYPOINT ["/init"]

CMD ["pure-ftpd", "/etc/pure-ftpd.conf"]
