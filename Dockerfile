FROM ubuntu:16.04

MAINTAINER Ondrej Galbavy "o.galbavy@pygmalios.com"

# nginx with ALPN and openssl 1.0.2
ENV NGINX_VERSION 1.11.5-1~xenial
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 &&\
    echo 'deb http://nginx.org/packages/mainline/ubuntu/ xenial nginx' > /etc/apt/sources.list.d/nginx.list &&\
    echo 'deb-src http://nginx.org/packages/mainline/ubuntu/ xenial nginx' >> /etc/apt/sources.list.d/nginx.list &&\
    apt-get update &&\
    apt-get install --no-install-recommends --no-install-suggests -y \
						ca-certificates \
						nginx=${NGINX_VERSION} \
						gettext-base \
    && rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

# https-portal
WORKDIR /root

ENV DOCKER_GEN_VERSION 0.7.0

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.11.0.1/s6-overlay-amd64.tar.gz /tmp/
ADD https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz /tmp/
ADD https://raw.githubusercontent.com/diafygi/acme-tiny/ecd26b1e784973e5b52d5a308964a8e29a6cf207/acme_tiny.py /bin/acme_tiny

RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / &&\
    tar -C /bin -xzf /tmp/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz && \
    rm /tmp/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz && \
    rm /tmp/s6-overlay-amd64.tar.gz && \
    rm /etc/nginx/conf.d/default.conf && \
    apt-get update && \
    apt-get install -y python ruby cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./fs_overlay /

RUN chmod a+x /bin/* && \
    chmod a+x /etc/cron.weekly/renew_certs

VOLUME /var/lib/https-portal

ENTRYPOINT ["/init"]
