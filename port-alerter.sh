#!/usr/bin/env bash

source "./config.sh"
source "./logger.sh"
source "./checks.sh"

declare -A REPORTED_SOCKS

DATA_PREFIX="$DATA_DIR/port-alerter"

function check_services() {
  local swarm_name=$SWARM_NAME
  while read -r service_name network_alias check_type check_value; do
    unique_name="${swarm_name} ${service_name} ${network_alias} ${check_type} ${check_value}"
    unique_code=$(echo "${unique_name,,}" | sed -e 's/ /_/g' -e 's/[^a-zA-Z0-9_-]/_/g')
    random_str=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 10)
    read -r unique_id _ < <(echo -n "$unique_name $random_str" | md5sum)
    prefix="${DATA_PREFIX}-${unique_code}"
    pending_file="${prefix}.pending"
    log_file="${prefix}.log"

    if [[ $check_type == "port" ]]; then
      port=$check_value
      real_port="$port"
      # used for testing
      if [[ -f "${DATA_PREFIX}-test-change-port-$port" ]]; then
        real_port=$(<"${DATA_PREFIX}-test-change-port-$port")
      fi
      WAIT="tcp://$network_alias:$real_port"
      WHERE="via mesh"
    fi

    if [[ $check_type == "sock" ]]; then
      IFS=":" read -r _sock_type sock_file <<<"$check_value"
      if [[ ! -S $sock_file ]]; then
        if [[ ! -v REPORTED_SOCKS[$sock_file] ]]; then
          log_warn "Sock file $sock_file does not exist locally!"
          REPORTED_SOCKS[$sock_file]=1
        fi
        continue
      fi
      WAIT="$check_value"
      WHERE="at $HOSTNAME"
    fi

    action=""
    appendix=""
    message="${swarm_name} service ${service_name} (${network_alias}:${check_value})"
    if ! /usr/local/bin/dockerize -timeout 5s -wait "$WAIT" true 2>"$log_file"; then
      if [[ -f $pending_file ]]; then
        log_warn "Pending alert: $message"
      else
        echo "$unique_id" >"$pending_file"
        action="create"
        appendix="not available $WHERE"
      fi
    else
      if [[ -f $pending_file ]]; then
        action="resolve"
        appendix="is available $WHERE"
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
  done < <(./services.sh)
}

log_info "Port alerter is entering loop with ${LOOP_SLEEP} sleep on entry ..."

while true; do
  sleep "$LOOP_SLEEP"
  check_services
done
