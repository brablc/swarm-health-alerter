#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

function check_nodes() {
  local active_node_count
  active_node_count=$(./nodes.sh | wc -l)
  local swarm_name=$SWARM_NAME
  local prefix="$DATA_DIR/swarm_failure"
  local pending_file="${prefix}.pending"
  local log_file="${prefix}.log"
  local where="at $HOSTNAME"

  ./nodes.sh --verbose >"$log_file"

  action=""
  appendix=""
  message="${swarm_name} swarm active managers count $active_node_count"
  if ((SWARM_MANAGER_MIN > active_node_count)); then
    if [[ -f $pending_file ]]; then
      log_warn "Pending alert: $message"
    else
      tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32 >"$pending_file"
      action="create"
      appendix="is less than $SWARM_MANAGER_MIN $where"
    fi
  else
    if [[ -f $pending_file ]]; then
      action="resolve"
      appendix="is ok $where"
      unique_id=$(cat "$pending_file")
      rm -f "$pending_file"
    fi
  fi
  if [[ -n $action ]]; then
    jq -n \
      --arg action "$action" \
      --arg unique_id "$unique_id" \
      --arg message "$message $appendix" \
      --arg summary "$(cat "$log_file")" \
      '{
         "action": $action,
         "unique_id": $unique_id,
         "message": $message,
         "summary": $summary
       }' | /bin/bash -c "$ALERT_SCRIPT"
  fi
  rm -f "$log_file"
}

log_info "Entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
  sleep "$LOOP_SLEEP"
  check_nodes
done
