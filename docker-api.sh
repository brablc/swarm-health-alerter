#!/usr/bin/env bash

VERSION="v1.43"

uri=$1
shift

if (( $# )); then
    uri="$uri?"
fi

while (( $# > 1 )); do
    key=$1
    value=$2
    shift 2
    uri="${uri}$key=$(echo $value | jq -s -R -r @uri)&"
done

if (( $# )); then
    uri="${uri}$1"
fi

if [[ "$NODE_TYPE" == "worker" && "$SWARM_API_URL" != "" ]]; then
    curl -s --fail-with-body "$SWARM_API_URL/$VERSION$uri"
else
    curl -s --fail-with-body --unix-socket /var/run/docker.sock "http://$VERSION$uri"
fi
