SCRIPT_NAME=${0##*/}
SCRIPT_PATH=$(readlink -f $0)
SCRIPT_DIR=${SCRIPT_PATH%/*}
cd "$SCRIPT_DIR"

export ALERTER_URL=${ALERTER_URL:-http://alerter:80}
export LABEL="swarm-health-alerter.port"
export LOGGER_USE_SYSLOG=0
export LOGGER_USE_TS=1
export LOOP_SLEEP=${LOOP_SLEEP:-10}
export SWARM_NAME=${SWARM_NAME:-Swarm}

export DATA_DIR=${DATA_DIR:-$script_dir/data}
