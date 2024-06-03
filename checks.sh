mkdir -p "$DATA_DIR"

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

if [[ -z $ALERT_SCRIPT  ]]; then
    log_error "Alert script not defined, alerting to console."
    export ALERT_SCRIPT="jq ."
fi
