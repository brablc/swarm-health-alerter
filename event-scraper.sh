#!/usr/bin/env bash

script_path=$(readlink -f $0)
script_dir=${script_path%/*}
cd "$script_dir"
source "./config.sh"
source "./logger.sh"

if [[ ! -S /var/run/docker.sock ]]; then
    log_error "Mount to /var/run/docker.sock missing?"
    exit 1
fi

if [[ -z $ALERTER_URL ]]; then
    log_warn "Missing ALERTER_URL, not passing scraped data"
else
    ./dockerize -wait ${ALERTER_URL/http/tcp} -timeout 10s true
fi

FIFO="$DATA_DIR/fifo_events"

mkfifo $FIFO
trap "rm -f $FIFO" EXIT
exec 3<> $FIFO # keep open
./docker-api.sh /events filters '{"type":["container"],"event":["create","destroy"]}' > $FIFO &
while read -r event < $FIFO; do
    result=$(jq --arg host "$HOSTNAME" -r '. | { host: $host, ts: .time, action: .Action, service_name: .Actor.Attributes["com.docker.swarm.service.name"]}' <<< "$event")
    if [ $? != 0 ]; then
        log_warn "Cannot parse event (multiple writers?):"
        echo "$event"
        continue
    fi
    [[ -z $ALERTER_URL ]] && continue
    curl -s -S "$ALERTER_URL?payload=$(echo "$result" | jq -s -R -r @uri)" -o /dev/null
done
