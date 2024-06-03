#!/usr/bin/env bash

network=${1?Expecting network name}
shift

NAME=swarm-health-alerter-test

docker run --rm \
    -it \
    --name $NAME \
    --network $network \
    --env ALERTER_URL="${ALERTER_URL:-http://localhost:80}" \
    --env ALERT_SCRIPT="${ALERT_SCRIPT}" \
    --env DATA_DIR=${DATA_DIR:-/app/data} \
    --env EVENTS_THRESHOLD="${EVENTS_THRESHOLD:-3}" \
    --env EVENTS_WINDOW="${EVENTS_WINDOW:-60}" \
    --env LOGGER_USE_TS="${LOGGER_USE_TS:-1}" \
    --env LOOP_SLEEP="${LOOP_SLEEP:-10s}" \
    --env SWARM_NAME="${SWARM_NAME:-Swarm}" \
    --env ZENDUTY_API_KEY="${ZENDUTY_API_KEY:-N/A}" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume .:/app/ \
    brablc/swarm-health-alerter:dev "$@"
