#!/usr/bin/env bash

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
cd "$script_dir"
source "./config.sh"
source "./logger.sh"

LOOP_SLEEP=${LOOP_SLEEP:-10}
ALERTER_URL=${ALERTER_URL:-http://alerter:80}

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

if [[ -z $ALERT_SCRIPT || ! -f $ALERT_SCRIPT ]]; then
    log_error "Alert script not defined or not accessible on \"$ALERT_SCRIPT\" path!"
    ALERT_SCRIPT="jq ."
fi

test -z "$SWARM_NAME" && log_warn "Env SWARM_NAME not defined using default"
swarm_name="${SWARM_NAME:-Swarm}"

# On all nodes start scraper, on manager node start alerter

services=$(./services.sh 2>&1)
if [ $? = 0 ]; then
    log_info "Initial list of services (run services.sh using docker exec to see actual):"
    echo "$services"
    log_info "Starting event alerter ..."
    ./event-alerter.py &
    trap "kill $!" EXIT
    log_info "Starting event scraper ..."
    ./event-scraper.sh &
    trap "kill $!" EXIT
else
    ./event-monitor.sh
    exit
fi

### Manager code only

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
        appendix=""
        message="${swarm_name} service ${service_name} (${network_alias}:${port})"
        ./dockerize -timeout 5s -wait tcp://$network_alias:$real_port true 2>$log_file
        if [ $? -ne 0 ]; then
            if [[ -f $pending_file ]]; then
                log_warn "Pending alert: $message"
            else
                echo "$unique_id" > $pending_file
                action="create"
                appendix="not available"
            fi
        else
            if [[ -f $pending_file ]]; then
                action="resolve"
                appendix="is available"
                unique_id=$(cat $pending_file)
                rm -f $pending_file
            fi
        fi
        if [[ -n $action ]]; then
            jq -n \
                --arg action    "$action" \
                --arg unique_id "$unique_id" \
                --arg message   "$message $appendix" \
                --arg summary   "$(jq -R -s @json $log_file)" \
                '{
                  "action": $action,
                  "unique_id": $unique_id,
                  "message": $message,
                  "summary": $log
                }' | /bin/bash -c "$ALERT_SCRIPT"
        fi
        rm -f $log_file
    done < <(./services.sh)
}

log_info "Entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
    sleep $LOOP_SLEEP
    check_services
done
