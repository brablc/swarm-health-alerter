# shellcheck disable=SC2034

SCRIPT_NAME=${0##*/}
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
cd "$SCRIPT_DIR"

export DISK_USAGE_MAX=${DISK_USAGE_MAX:-85}
export LABEL_PORT="swarm-health-alerter.port"
export LABEL_SOCK="swarm-health-alerter.sock"
export LOGGER_USE_SYSLOG=0
export LOGGER_USE_TS=1
export LOOP_SLEEP=${LOOP_SLEEP:-10}
export SWARM_NAME=${SWARM_NAME:-Swarm}
export SWARM_MANAGER_MIN=${SWARM_MANAGER_MIN:-3}

export DATA_DIR=${DATA_DIR:-$script_dir/data}
