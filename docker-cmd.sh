#!/usr/bin/env bash

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
source "$script_dir/config.sh"
source "$script_dir/logger.sh"

LOOP_SLEEP=${LOOP_SLEEP:-10s}

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

test -z "$ALERT_SCRIPT" && log_warn "Env ALERT_SCRIPT not defined - alerting disabled"
test -z "$SWARM_NAME" && log_warn "Env SWARM_NAME not defined using default"

swarm_name="${SWARM_NAME:-Swarm}"
DATA_DIR=${DATA_DIR:-$script_dir/data}
mkdir -p $DATA_DIR

if [[ -n $ALERT_SCRIPT && ! -f $ALERT_SCRIPT ]]; then
    log_error "Alert script defined but not accessible on $ALERT_SCRIPT path!"
    ALERT_SCRIPT="jq ."
fi

function check_services() {
    while read service_name network_alias port; do
        unique_name=$(echo "${swarm_name} ${service_name} ${network_alias} ${port}" )
        unique_code=$(echo "${unique_name,,}" | sed -e 's/ /_/g' -e 's/[^a-zA-Z0-9_-]/_/g')
        random_str=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
        read unique_id _ < <(echo -n "$unique_name $random_str" | md5sum)
        prefix="$DATA_DIR/${unique_code}"
        pending_file="${prefix}.pending"
        log_file="${prefix}.log"
        # used for testing
        real_port="$port"
        if [[ -f "$DATA_DIR/test-change-port-$port" ]]; then
            real_port=$(< "$DATA_DIR/test-change-port-$port")
        fi
        action=""
        ./dockerize -timeout 5s -wait tcp://$network_alias:$real_port true 2>$log_file
        if [ $? -ne 0 ]; then
            if [[ -f $pending_file ]]; then
                log_warn "$service_name|$network_alias:$port|Pending alert"
            else
                log_error "$service_name|$network_alias:$port|Creating alert"
                echo "$unique_id" > $pending_file
                action="create"
            fi
        else
            if [[ -f $pending_file ]]; then
                log_info "$service_name|$network_alias:$port|Resolving alert"
                action="resolve"
                unique_id=$(cat $pending_file)
                rm -f $pending_file
            fi
        fi
        if [[ -n $action ]]; then
            jq -n \
                --arg action        "$action" \
                --arg unique_id     "$unique_id" \
                --arg swarm_name    "$swarm_name" \
                --arg service_name  "$service_name" \
                --arg network_alias "$network_alias" \
                --arg port          "$port" \
                --arg log           "$(jq -R -s @json $log_file)" \
                '{
                  "action": $action,
                  "unique_id": $unique_id,
                  "swarm_name": $swarm_name,
                  "service_name": $service_name,
                  "network_alias": $network_alias,
                  "port": $port,
                  "log": $log
                }' | /bin/bash -c "$ALERT_SCRIPT"
        fi
        rm -f $log_file
    done < <(./services.sh)
}

log_info "Initial list of services (run services.sh using docker exec to see actual):"
./services.sh

log_info "Entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
    sleep $LOOP_SLEEP
    check_services
done
