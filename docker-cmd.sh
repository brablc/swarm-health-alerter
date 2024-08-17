#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

export NODE_TYPE=manager
services=$(./services.sh 2>&1)
if [ $? != 0 ]; then
    export NODE_TYPE=worker
    services=$(./services.sh 2>&1)
fi

if [[ "$services" != "" ]]; then
    log_info "Starting port/sock alerter (initial list of services) ..."
    echo "$services"

    ./port-alerter.sh &
    trap "kill $!" EXIT
fi

log_info "Starting event alerter ..."
./event-alerter.py
