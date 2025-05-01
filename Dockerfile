FROM alpine:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV URL="https://www.infradead.org/ocserv/download/"
ENV BUILD_DEPS=" \
  make gcc coreutils build-base build-base \
  xz gawk pkgconfig nettle-dev gnutls-dev \
  libev-dev readline-dev lz4-dev libseccomp-dev \
  oath-toolkit-dev libnl3-dev talloc-dev http-parser-dev \
  radcli-dev linux-pam-dev krb5-dev protobuf-c-dev"

RUN apk add --no-cache \
  bash curl ${BUILD_DEPS} \
  certbot certbot-dns-cloudflare iptables ipcalc

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x \
  && curl -sL "${URL}" | \
    grep -oE 'ocserv-([0-9]{1,}\.)+[0-9]{1,}\.tar\.xz' | \
    sort -V | tail -n1 | \
    xargs -I {} curl -sLo ocserv.tar.xz "${URL}{}" \
  && tar -xf ocserv.tar.xz && cd ocserv-* \
  && ./configure \
  && make && make install && make clean \
  && cd .. && rm -rf ocserv-* ocserv.tar.xz \
  && apk del --purge ${BUILD_DEPS} \
  && rm -rf /var/cache/apk/* \
  && rm -rf /etc/ocserv/ocserv.conf

WORKDIR /etc/ocserv

COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
