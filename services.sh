#!/usr/bin/env bash

source ./logger.sh

sock=/var/run/docker.sock
url=http://v1.45

LABEL="swarm-health-alerter.port"

curl -s --unix-socket $sock $url/services -o /tmp/services

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
        read service_id replicas < <(get_service $service | jq -r '"\(.ID) \(.Spec.Mode.Replicated.Replicas)"')
        test "$replicas" != "0" || continue

        if [[ $replicas == "null" ]]; then
            filter=$(echo '{"service":["'$service_id'"], "desired-state":["running"]}' | jq -s -R -r @uri)
            read state message exit_code < <(curl -s --unix-socket $sock "$url/tasks?filters=$filter" | jq -r '.[] | "\(.Status.State) \(.Status.Message) \(.ContainerStatus.ExitCode)"' | grep running | head -1)

            test "$state" == "running" || break
        fi

        echo "$service $network_alias $port"

    done
done < <(get_services)
