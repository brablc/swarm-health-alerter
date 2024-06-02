#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

sock=/var/run/docker.sock
url=http://v1.45

LABEL="swarm-health-alerter.port"

curl -s --fail-with-body --unix-socket $sock $url/servicess -o /tmp/services
if [ $? -ne 0 ]; then
    log_error "$(jq -r .message /tmp/services 2>/dev/null || cat /tmp/services)"
    exit 1
fi

function get_services() {
    cat /tmp/services | jq -r '.[] | select(.Spec.Labels["com.docker.stack.namespace"] != null) | .Spec.Name' | sort -u
}

function get_service() {
    local service="$1"
    cat /tmp/services | jq -r '.[] | select(.Spec.Name=="'$service'")'
}

while read service; do
    ports=$(get_service $service | jq -r '.Spec.Labels["'$LABEL'"]')
    test "$ports" != "null" || continue

    network_alias=$(get_service $service | jq -r '.Spec.TaskTemplate.Networks[].Aliases[]' | sort | head -1)

    echo $ports | sed 's/,/\n/g' | while read port; do
        read service_id mode replicas < <(get_service $service | jq -r '"\(.ID) \(.Spec.Mode | keys[0]) \(.Spec.Mode.Replicated.Replicas)"')
        if [[ $mode == "Global" || ( $mode == "Replicated" && "$replicas" != "0" ) ]]; then
            echo "$service $network_alias $port"
        fi
    done
done < <(get_services)
