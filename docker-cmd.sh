#!/usr/bin/env bash

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
cd "$script_dir"
source "./config.sh"
source "./logger.sh"

export LOOP_SLEEP=${LOOP_SLEEP:-10}
export ALERTER_URL=${ALERTER_URL:-http://alerter:80}
export SWARM_NAME=${SWARM_NAME:-Swarm}

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

if [[ -z $ALERT_SCRIPT || ! -f $ALERT_SCRIPT ]]; then
    log_error "Alert script not defined or not accessible on \"$ALERT_SCRIPT\" path!"
    export ALERT_SCRIPT="jq ."
fi

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
