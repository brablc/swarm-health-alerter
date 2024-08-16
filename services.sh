#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

./docker-api.sh /services > /tmp/services
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

    ports=$(get_service $service_name | jq -r '.Spec.Labels["'$LABEL_PORT'"]')
    socks=$(get_service $service_name | jq -r '.Spec.Labels["'$LABEL_SOCK'"]')

    if [[ "$ports" != "null" || "$socks" != "null" ]]; then
        network_alias=$(get_service $service_name | jq -r '.Spec.TaskTemplate.Networks[].Aliases[]' | sort | head -1)
        read service_id mode replicas < <(get_service $service_name | jq -r '"\(.ID) \(.Spec.Mode | keys[0]) \(.Spec.Mode.Replicated.Replicas)"')
        [[ $mode == "Replicated" && $replicas == 0 ]] && continue

        if [[ "$ports" != "null" ]]; then
            echo "$ports" | sed 's/,/\n/g' | while read port; do echo "$service_name $network_alias port $port"; done
        fi

        if [[ "$socks" != "null" ]]; then
            echo "$socks" | sed 's/,/\n/g' | while read sock; do echo "$service_name $network_alias sock $sock"; done
        fi
    fi
done < <(get_services)
