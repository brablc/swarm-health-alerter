FROM alpine:latest

ENV DOCKERIZE_VERSION v0.7.0

WORKDIR /app

COPY *.sh ./
COPY integrations/ integrations/

RUN apk update --no-cache \
    && apk add --no-cache bash curl jq openssl \
    && curl -s -L https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzf - -C .

CMD ["./docker-cmd.sh"]
