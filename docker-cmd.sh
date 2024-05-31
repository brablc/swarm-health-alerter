#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

LOOP_SLEEP=${LOOP_SLEEP:-10s}

test -z "$ALERT_SCRIPT" && log_warn "Env ALERT_SCRIPT not defined - alerting disabled"
test -z "$SWARM_NAME" && log_warn "Env SWARM_NAME not defined using default"

if [[ -n $ALERT_SCRIPT && ! -f $ALERT_SCRIPT ]]; then
    log_err "Alert script defined but not accessible on $ALERT_SCRIPT path"
    ALERT_SCRIPT=""
fi

function check_services() {
    while read service network_alias port; do
        prefix="/tmp/alert-$(echo "$service $network_alias:$port" | base64)"
        alert_file=${prefix}-alert
        log_file=${prefix}-log
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
                log_error "$service|$network_alias:$port|New alert"
                echo "$service $network_alias:$port"> $alert_file
                if [[ -n $ALERT_SCRIPT ]]; then
                    cat $log_file | /bin/bash -c "$ALERT_SCRIPT CREATE '$service' '$network_alias' '$port'"
                fi
                cat $log_file
            fi
        else
            if [[ -f $alert_file ]]; then
                log_info "$service|$network_alias:$port|Resolved alert"
                if [[ -n $ALERT_SCRIPT ]]; then
                    cat $log_file | /bin/bash -c "$ALERT_SCRIPT RESOLVE '$service' '$network_alias' '$port'"
                fi
                rm -f $alert_file
            fi
        fi
    done < <(./services.sh)
}

log_info "Initial list of services (run services.sh using docker exec to see actual):"
./services.sh

log_info "Entering loop with ${LOOP_SLEEP} sleep ..."

while true; do
    sleep $LOOP_SLEEP
    check_services
done
