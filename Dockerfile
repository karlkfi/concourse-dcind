FROM alpine:3.7

LABEL maintainer="Tom Reeb <reebzor@gmail.com>" \
      name="tomreeb/concourse-dgossind" \
      version="0.1"

ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=17.12.1-ce \
    DOCKER_COMPOSE_VERSION=1.19.0 \
    DOCKER_SQUASH=0.2.0 \
    GOSS_VERSION=0.3.6 \
    GOSS_FILES_STRATEGY=cp \
    GOSS_PATH=/bin/goss \
    DGOSS_PATH=/bin/dgoss

RUN apk --update --no-cache add \
        bash \
        curl \
        device-mapper \
        py-pip \
        iptables \
        util-linux \
        ca-certificates \
        make \
        && \
    apk upgrade && \
    curl -fL "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" | tar zx && \
    mv /docker/* /bin/ && chmod +x /bin/docker* && \
    pip install docker-compose==${DOCKER_COMPOSE_VERSION} && \
    curl -fL "https://github.com/jwilder/docker-squash/releases/download/v${DOCKER_SQUASH}/docker-squash-linux-amd64-v${DOCKER_SQUASH}.tar.gz" | tar zx && \
    mv /docker-squash* /bin/ && chmod +x /bin/docker-squash* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /root/.cache && \
    curl -L https://raw.githubusercontent.com/aelsabbahy/goss/master/extras/dgoss/dgoss -o ${DGOSS_PATH} && \
    chmod +rx ${DGOSS_PATH} && \
    curl -L https://github.com/aelsabbahy/goss/releases/download/v${GOSS_VERSION}/goss-linux-amd64 -o ${GOSS_PATH}

COPY entrypoint.sh /bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
