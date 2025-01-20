#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

DATA_PREFIX="$DATA_DIR/disk-alerter"

function check_disks() {
  local swarm_name=$SWARM_NAME
  while read -r mount usage; do
    unique_name="${swarm_name} ${mount}"
    unique_code=$(echo "${unique_name,,}" | sed -e 's/ /_/g' -e 's/[^a-zA-Z0-9_-]/_/g')
    random_str=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 10)
    read -r unique_id _ < <(echo -n "$unique_name $random_str" | md5sum)
    prefix="${DATA_PREFIX}-${unique_code}"
    pending_file="${prefix}.pending"
    log_file="${prefix}.log"

    df -h "$mount" >"$log_file"

    action=""
    appendix=""
    message="${swarm_name} disk ${mount:7:24} at $HOSTNAME usage $usage% >= $DISK_USAGE_MAX"
    if ((usage >= DISK_USAGE_MAX)); then
      if [[ -f $pending_file ]]; then
        log_warn "Pending alert: $message"
      else
        echo "$unique_id" >"$pending_file"
        action="create"
        appendix="is out of space"
      fi
    else
      if [[ -f $pending_file ]]; then
        action="resolve"
        appendix="has space"
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
  done < <(df -h -PT | awk -vlimit="$DISK_MAX_USAGE" 'NR>1&&int($6)>limit&&/rootfs/ {print($7,int($6))}')
}

log_info "Disk alerter is entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
  sleep "$LOOP_SLEEP"
  check_disks
done
