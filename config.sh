export SCRIPT_NAME=${0##*/}
export LOGGER_USE_TS=1
export LOGGER_USE_SYSLOG=0
export DATA_DIR=${DATA_DIR:-$script_dir/data}
mkdir -p $DATA_DIR
