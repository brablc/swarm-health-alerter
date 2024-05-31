#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

SLEEP=${SLEEP-10s}

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
                cat $log_file
            fi
        else
            if [[ -f $alert_file ]]; then
                log_info "$service|$network_alias:$port|Resolved alert"
                rm -f $alert_file
            fi
        fi
    done < <(./services.sh)
}

log_info "Initial list of services (run services.sh using docker exec to see actual):"
./services.sh

log_info "Entering loop with ${SLEEP} sleep ..."

while true; do
    sleep $SLEEP
    check_services
done
