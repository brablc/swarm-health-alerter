#!/usr/bin/env bash

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
source "$script_dir/../logger.sh"

DATA_DIR=${DATA_DIR:-$script_dir/../data}

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
entity_id=$(jq -r .unique_id $input_file)

alert_type=""
appendix=""
case $action in
    create )
        alert_type="critical"
        appendix="not available"
        ;;
    resolve )
        alert_type="resolved"
        appendix="is available"
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
        "message": "\(.swarm_name) service \(.service_name) (\(.network_alias):\(.port)) \($appendix)",
        "summary": .log
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
