#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

if ! ./docker-api.sh /nodes >/tmp/nodes; then
  log_error "$(jq -r .message /tmp/nodes 2>/dev/null || cat /tmp/nodes)"
  exit 1
fi

if [[ $1 == "--verbose" ]]; then
  cat /tmp/nodes | jq '.[] | select(.Spec.Role == "manager") |
    {
      hostname: .Description.Hostname,
      leader: (.ManagerStatus.Leader // false),
      status: .Status,
      spec: .Spec
    }'
else
  cat /tmp/nodes | jq -r '.[] | select(.Spec.Role == "manager") | select(.Status.State == "ready") | "\(.Description.Hostname) \(.ManagerStatus.Leader // false)"' | sort -u
fi
