#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

function check_services() {
    local swarm_name=$SWARM_NAME
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
                --arg summary   "$(cat $log_file)" \
                '{
                  "action": $action,
                  "unique_id": $unique_id,
                  "message": $message,
                  "summary": $summary
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
