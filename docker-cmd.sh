#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

LOOP_SLEEP=${LOOP_SLEEP:-10s}

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

test -z "$ALERT_SCRIPT" && log_warn "Env ALERT_SCRIPT not defined - alerting disabled"
test -z "$SWARM_NAME" && log_warn "Env SWARM_NAME not defined using default"

SWARM_NAME="${SWARM_NAME:-Swarm}"

if [[ -n $ALERT_SCRIPT && ! -f $ALERT_SCRIPT ]]; then
    log_error "Alert script defined but not accessible on $ALERT_SCRIPT path"
    ALERT_SCRIPT=""
fi

function check_services() {
    local swarm_name=$SWARM_NAME
    while read service network_alias port; do
        read unique_id rest < <(echo "${swarm_name}_${service}_${network_alias}_${port}" | md5sum)
        prefix="/tmp/alerter-${unique_id}"
        alert_file=${prefix}.pending
        log_file=${prefix}.log
        # used for testing
        real_port=$port
        if [[ -f test-change-port-$port ]]; then
            read real_port < test-change-port-$port
        fi
        ./dockerize -timeout 5s -wait tcp://$network_alias:$real_port true 2>$log_file
        if [ $? -ne 0 ]; then
            if [[ -f $alert_file ]]; then
                log_warn "$service|$network_alias:$port|Pending alert"
            else
                log_error "$service|$network_alias:$port|Creating alert"
                echo "$service $network_alias:$port"> $alert_file
                if [[ -n $ALERT_SCRIPT ]]; then
                    cat $log_file | /bin/bash -c "$ALERT_SCRIPT CREATE '$swarm_name' '$service' '$network_alias' '$port'"
                fi
                cat $log_file
            fi
        else
            if [[ -f $alert_file ]]; then
                log_info "$service|$network_alias:$port|Resolving alert"
                if [[ -n $ALERT_SCRIPT ]]; then
                    cat $log_file | /bin/bash -c "$ALERT_SCRIPT RESOLVE '$SWARM_NAME' '$service' '$network_alias' '$port'"
                fi
                rm -f $alert_file
            fi
            rm -f $log_file
        fi
    done < <(./services.sh)
}

log_info "Initial list of services (run services.sh using docker exec to see actual):"
./services.sh

log_info "Entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
    sleep $LOOP_SLEEP
    check_services
done
