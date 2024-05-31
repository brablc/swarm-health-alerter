#!/usr/bin/env bash

set -e

network=${1?Expecting network name}

docker run -it --rm \
    --name swarm-health-alerter-test \
    --network $network \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume .:/app/ \
    brablc/swarm-health-alerter:dev
