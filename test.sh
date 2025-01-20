#!/usr/bin/env bash

source "./logger.sh"

# Build: docker build -t brablc/swarm-health-alerter:dev .

PARAMS=(
  --env SWARM_API_URL="http://swarm-api:2375"
  --env ALERT_SCRIPT="${ALERT_SCRIPT}"
  --env DATA_DIR="${DATA_DIR:-/app/data}"
  --env EVENTS_THRESHOLD="${EVENTS_THRESHOLD:-3}"
  --env EVENTS_WINDOW="${EVENTS_WINDOW:-60}"
  --env LOGGER_USE_TS="${LOGGER_USE_TS:-1}"
  --env LOOP_SLEEP="${LOOP_SLEEP:-10}"
  --env SWARM_NAME="${SWARM_NAME:-Swarm}"
  --env ZENDUTY_API_KEY="${ZENDUTY_API_KEY:-N/A}"
  --volume /:/rootfs:ro
  --volume /var/run/docker.sock:/var/run/docker.sock
  --volume .:/app/
)

if [[ $# == 0 ]]; then
  echo "Usage: test.sh NETWORK[..]" >&2
  exit 1
fi

container_name="swarm-health-alerter-test"

log_info "Create container: $container_name ..."
docker create --rm --tty --name "$container_name" "${PARAMS[@]}" brablc/swarm-health-alerter:dev

for network in "$@"; do
  log_info "Attach network $network ..."
  if ! docker network connect "$network" "$container_name"; then
    log_error "Failed to attach network: $network"
  fi
done

function cleanup() {
  log_info "Stopping container: $container_name ..."
  docker stop "$container_name"
  log_info "Done"
}

trap cleanup SIGINT

log_info "Starting container: $container_name ..."
docker start --attach --interactive "$container_name"
