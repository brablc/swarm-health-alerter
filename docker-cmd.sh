#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

log_info "Starting event alerter ..."
./event-alerter.py &
trap "kill $!" EXIT

services=$(./services.sh 2>&1)
if [ $? != 0 ]; then
    exit
fi

log_info "Initial list of services:"
echo "$services"

log_info "Starting port alerter ..."
./port-alerter.sh
