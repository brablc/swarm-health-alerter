FROM python:3.12-alpine

ENV DOCKERIZE_VERSION v0.7.0

ENV DATA_DIR=/data

WORKDIR /app

RUN mkdir -p "$DATA_DIR"

COPY *.sh ./
COPY *.py ./
COPY integrations/ integrations/

RUN apk update --no-cache \
    && apk add --no-cache bash curl jq openssl \
    && curl -s -L https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzf - -C .

CMD ["./docker-cmd.sh"]
