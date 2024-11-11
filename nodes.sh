#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

./docker-api.sh /nodes >/tmp/nodes
if [ $? -ne 0 ]; then
  log_error "$(jq -r .message /tmp/nodes 2>/dev/null || cat /tmp/nodes)"
  exit 1
fi

cat /tmp/nodes | jq -r '.[] | select(.Spec.Role == "manager") | select(.Status.State == "ready") | "\(.Description.Hostname) \(.ManagerStatus.Leader // false)"' | sort -u
