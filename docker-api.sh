#!/usr/bin/env bash

url=$1
shift

if (( $# )); then
    url="$url?"
fi

while (( $# > 1 )); do
    key=$1
    value=$2
    shift 2
    url="${url}$key=$(echo $value | jq -s -R -r @uri)&"
done

if (( $# )); then
    url="${url}$1"
fi

curl -s --fail-with-body --unix-socket /var/run/docker.sock "http://v1.45$url"
