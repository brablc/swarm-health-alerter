#!/usr/bin/env bash

source ./config.sh
source ./logger.sh

SLEEP=${SLEEP-10s}

function get_cmd() {
    cmd=(./dockerize -timeout 300s -wait-retry-interval 5s)
    while read SERVICE; do
        cmd+=(-wait $SERVICE)
    done < <(./services.sh)
    cmd+=(touch $OK_FILE)
    echo ${cmd[@]}
}

log_info "Entering loop with ${SLEEP} sleep ..."

while true; do
    eval $(get_cmd)
    if [ -f $OK_FILE ]; then
        log_info OK
        sleep $SLEEP
        rm -f $OK_FILE
    else
        log_error TIMEOUT
    fi
done
