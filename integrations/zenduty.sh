#!/usr/bin/env bash

SCRIPT_PATH=$(readlink -f $0)
SCRIPT_DIR=${SCRIPT_PATH%/*}
source "$SCRIPT_DIR/../logger.sh"

DATA_DIR=${DATA_DIR:-$SCRIPT_DIR/../data}

input_file=$(mktemp $DATA_DIR/zenduty-input.XXXXXX)
trap "rm -f $input_file" EXIT

if ! timeout 2s cat > $input_file; then
    log_error "Reading from stdin timed out."
    exit 1
fi

if [[ -z $ZENDUTY_API_KEY ]]; then
    log_error "Expecting ZENDUTY_API_KEY env"
    exit 1
fi

action=$(jq -r .action $input_file)
message=$(jq -r .message $input_file)
entity_id=$(jq -r .unique_id $input_file)

alert_type=""
case $action in
    create )
        alert_type="critical"
        log_error "Creating alert: $message"
        ;;
    resolve )
        alert_type="resolved"
        log_info "Resolving alert: $message"
        ;;
    *)
        log_error "Action must be one of: create resolve. Received: '$action'"
        ;;
esac

request_file=$DATA_DIR/${entity_id}-zenduty-request.json
response_file=$DATA_DIR/${entity_id}-zenduty-response.json

jq -r \
    --arg alert_type "$alert_type" \
    --arg appendix "$appendix" \
    '{
        "alert_type": $alert_type,
        "entity_id": .unique_id,
        "message": .message,
        "summary": .summary
    }' $input_file > $request_file

log_info "Request file:"
jq . $request_file 2>/dev/null || cat $request_file

url="https://www.zenduty.com/api/events/${ZENDUTY_API_KEY}/"
curl -s -X POST "$url" -H 'Content-Type: application/json' -d @$request_file >$response_file
return_code=$?

if [ $return_code -ne 0 ]; then
    log_error "Curl failed with code $return_code"
fi

log_info "Response file:"
jq . $response_file 2>/dev/null || cat $response_file

if [[ $action == "resolve" ]]; then
    rm -f $request_file
    rm -f $response_file
fi
