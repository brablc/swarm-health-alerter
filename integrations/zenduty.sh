#!/usr/bin/env bash

echo "Reading log file from stdin ..." >&2
summary=$(cat | jq -Rs .)

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
source "$script_dir/../config.sh"
source "$script_dir/../logger.sh"

if [[ -z $ZENDUTY_API_KEY ]]; then
    log_error "Expecting ZENDUTY_API_KEY env"
    exit 1
fi

if [[ $# != 4 ]]; then
    log_error "Expecting parameters: ACTION SERVICE_NAME NETWORK_ALIAS PORT"
    exit 1
fi

ACTION=$1
SERVICE_NAME=$2
NETWORK_ALIAS=$3
PORT=$4

alert_type=""
case $ACTION in
    CREATE )
        alert_type="critical"
        ;;
    RESOLVE )
        alert_type="resolved"
        ;;
    *)
        log_error "Action must be one of: CREATE RESOLVE. Received: '$ACTION'"
        ;;
esac

SWARM_NAME="${SWARM_NAME:-Swarm}"

entity_id="${SWARM_NAME}_${SERVICE_NAME}_${NETWORK_ALIAS}_${PORT}"
entity_id=${entity_id,,}
entity_id=${entity_id// /_}


url="https://www.zenduty.com/api/events/${ZENDUTY_API_KEY}/"
response_file=/tmp/response-${entity_id}
cat << __PAYLOAD | curl -s -X POST "$url" -H 'Content-Type: application/json' -d @- >$response_file 2>&1
{
    "alert_type": "$alert_type",
    "entity_id": "$entity_id",
    "message":"$SWARM_NAME service $SERVICE_NAME ($NETWORK_ALIAS:$PORT) not available",
    "summary": $summary
}
__PAYLOAD
return_code=$?

if [ $return_code -ne 0 ]; then
    log_error "Curl failed with code $return_code"
    cat $response_file
else
    jq . < $response_file
fi
