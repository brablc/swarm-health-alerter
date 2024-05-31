#!/usr/bin/env bash

SOCK=/var/run/docker.sock
URL=http://v1.45/services

LABEL="swarm-health-alerter.port"

function get_services() {
    curl -s --unix-socket $SOCK $URL \
        | jq -r '.[] | select(.Spec.Labels["com.docker.stack.namespace"] != null) | .Spec.Name'
}

while read service; do
    ports=$(curl -s --unix-socket $SOCK $URL/$service | jq -r '.Spec.Labels["'$LABEL'"]')
    test "$ports" != "null" || continue
    network_alias=$(curl -s --unix-socket $SOCK $URL/$service | jq -r '.Spec.TaskTemplate.Networks[].Aliases[]' | sort | head -1)
    echo $ports | sed 's/,/\n/g' | while read port; do echo "tcp://$network_alias:$port"; done
done < <(get_services)
