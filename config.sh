SCRIPT_NAME=${0##*/}

export LOOP_SLEEP=${LOOP_SLEEP:-10}
export ALERTER_URL=${ALERTER_URL:-http://alerter:80}
export SWARM_NAME=${SWARM_NAME:-Swarm}
export LOGGER_USE_TS=1
export LOGGER_USE_SYSLOG=0

export DATA_DIR=${DATA_DIR:-$script_dir/data}
mkdir -p $DATA_DIR

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

if [[ -z $ALERT_SCRIPT ]]; then
    log_error "Alert script not defined!"
    export ALERT_SCRIPT="jq ."
fi

if [[ ! -f $ALERT_SCRIPT ]]; then
    || ! -f $ALERT_SCRIPT ]]; then
    log_error "Alert script not accessible on $ALERT_SCRIPT path!"
    export ALERT_SCRIPT="jq ."
fi
