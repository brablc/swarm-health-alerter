#!/usr/bin/env bash

network=${1?Expecting network name}
shift

NAME=swarm-health-alerter-test

docker run --rm \
    -it \
    --name $NAME \
    --network $network \
    --env SLEEP="$SLEEP" \
    --env ALERT_SCRIPT="$ALERT_SCRIPT" \
    --env SWARM_NAME="$SWARM_NAME" \
    --env ZENDUTY_API_KEY="$ZENDUTY_API_KEY" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume .:/app/ \
    brablc/swarm-health-alerter:dev "$@"
