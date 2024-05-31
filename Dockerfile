FROM alpine:latest

ENV DOCKERIZE_VERSION v0.7.0

WORKDIR /app

COPY *.sh ./

RUN apk update --no-cache \
    && apk add --no-cache bash curl jq openssl \
    && curl -s -L https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzf - -C .

HEALTHCHECK \
    --interval=10s \
    --timeout=301s \
    --retries=2 \
    --start-period=300s \
    CMD ./docker-healthcheck.sh

CMD ["./docker-cmd.sh"]
