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

if [[ $# != 5 ]]; then
    log_error "Expecting parameters: ACTION SWARM_NAME SERVICE_NAME NETWORK_ALIAS PORT"
    exit 1
fi

ACTION=$1
SWARM_NAME=$2
SERVICE_NAME=$3
NETWORK_ALIAS=$4
PORT=$5

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

read entity_id rest < <(echo "${SWARM_NAME}_${SERVICE_NAME}_${NETWORK_ALIAS}_${PORT}" | md5sum)

request_file=/tmp/zenduty-request-${entity_id}.json
response_file=/tmp/zenduty-response-${entity_id}.json

cat << __PAYLOAD > $request_file
{
    "alert_type": "$alert_type",
    "entity_id": "$entity_id",
    "message":"$SWARM_NAME service $SERVICE_NAME ($NETWORK_ALIAS:$PORT) not available",
    "summary": $summary
}
__PAYLOAD

log_info "Request file:"
jq . $request_file 2>/dev/null || cat $request_file

url="https://www.zenduty.com/api/events/${ZENDUTY_API_KEY}/"
curl -s -X POST "$url" -H 'Content-Type: application/json' -d @$request_file >$response_file 2>&1
return_code=$?

if [ $return_code -ne 0 ]; then
    log_error "Curl failed with code $return_code"
fi

log_info "Response file:"
jq . $response_file 2>/dev/null || cat $response_file

if [[ $ACTION == "RESOLVE" ]]; then
    rm -f $request_file
    rm -f $response_file
fi
