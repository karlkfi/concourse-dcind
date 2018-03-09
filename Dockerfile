FROM alpine:3.7

ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=17.12.1-ce \
    DOCKER_COMPOSE_VERSION=1.19.0 \
    DOCKER_SQUASH=0.2.0

# Install Docker, Docker Compose, Docker Squash
RUN apk --update --no-cache add \
        bash \
        curl \
        device-mapper \
        py-pip \
        iptables \
        ca-certificates \
        && \
    apk upgrade && \
    curl -fL "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" | tar zx && \
    mv /docker/* /bin/ && chmod +x /bin/docker* && \
    pip install docker-compose==${DOCKER_COMPOSE_VERSION} && \
    curl -fL "https://github.com/jwilder/docker-squash/releases/download/v${DOCKER_SQUASH}/docker-squash-linux-amd64-v${DOCKER_SQUASH}.tar.gz" | tar zx && \
    mv /docker-squash* /bin/ && chmod +x /bin/docker-squash* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /root/.cache

COPY entrypoint.sh /bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
