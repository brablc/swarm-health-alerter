#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

sock=/var/run/docker.sock
url=http://v1.45

LABEL="swarm-health-alerter.port"

curl -s --fail-with-body --unix-socket $sock $url/services -o /tmp/services
if [ $? -ne 0 ]; then
    log_error "$(jq -r .message /tmp/services 2>/dev/null || cat /tmp/services)"
    exit 1
fi

function get_services() {
    cat /tmp/services | jq -r '.[] | select(.Spec.Labels["com.docker.stack.namespace"] != null) | .Spec.Name' | sort -u
}

function get_service() {
    local service_name="$1"
    cat /tmp/services | jq -r '.[] | select(.Spec.Name=="'$service_name'")'
}

while read service_name; do
    ports=$(get_service $service_name | jq -r '.Spec.Labels["'$LABEL'"]')

    if [[ "$ports" != "null" ]]; then
        network_alias=$(get_service $service_name | jq -r '.Spec.TaskTemplate.Networks[].Aliases[]' | sort | head -1)
        read service_id mode replicas < <(get_service $service_name | jq -r '"\(.ID) \(.Spec.Mode | keys[0]) \(.Spec.Mode.Replicated.Replicas)"')
        [[ $mode == "Replicated" && $replicas == 0 ]] && continue

        echo $ports | sed 's/,/\n/g' | while read port; do echo "$service_name $network_alias $port"; done
    fi
done < <(get_services)
