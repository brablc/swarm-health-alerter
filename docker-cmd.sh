#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

services=$(./services.sh 2>&1)
if [ $? = 0 ]; then
    log_info "Initial list of services:"
    echo "$services"

    log_info "Starting port alerter ..."
    ./port-alerter.sh &
    trap "kill $!" EXIT
fi

log_info "Starting event alerter ..."
./event-alerter.py
