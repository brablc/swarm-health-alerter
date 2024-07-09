#!/usr/bin/env python3

import hashlib
import json
import os
import requests
import requests_unixsocket
import secrets
import socket
import string
import subprocess
import time
import threading
import urllib.parse as urlparse

from collections import defaultdict, deque
from logger import log_info, log_error

ALERT_SCRIPT = os.getenv("ALERT_SCRIPT", "jq .")
EVENTS_WINDOW = int(os.getenv("EVENTS_WINDOW", "120"))
EVENTS_THRESHOLD = int(os.getenv("EVENTS_THRESHOLD", "2"))
HOSTNAME = os.getenv("HOSTNAME", socket.gethostname())
LOOP_SLEEP = int(os.getenv("LOOP_SLEEP", "10"))
SWARM_NAME = os.getenv("SWARM_NAME", "Swarm")

events = deque()
pending_alerts = {}
lock = threading.Lock()


def calculate_md5(input_str):
    md5_hash = hashlib.md5()
    md5_hash.update(input_str.encode("utf-8"))
    return md5_hash.hexdigest()


def send_alert(data):
    if not ALERT_SCRIPT:
        return

    json_data = json.dumps(data)
    process = subprocess.Popen(
        ["/bin/bash", "-c", ALERT_SCRIPT], stdin=subprocess.PIPE, text=True
    )
    process.communicate(input=json_data)


def get_random_str(length):
    characters = string.ascii_letters + string.digits
    return "".join(secrets.choice(characters) for _ in range(length))


def docker_events_stream():
    base_url = "http+unix://"
    socket_path = "/var/run/docker.sock"
    endpoint = "/v1.41/events"
    url = f"{base_url}{urlparse.quote(socket_path, safe='')}{endpoint}"

    params = {
        "filters": json.dumps(
            {"type": ["container"], "event": ["create", "destroy", "exec_die"]}
        )
    }

    session = requests_unixsocket.Session()
    response = session.get(url, params=params, stream=True)
    response.raise_for_status()

    for line in response.iter_lines():
        if line:
            yield json.loads(line.decode("utf-8"))


def process_events():
    current_time = time.time()

    counts = defaultdict(lambda: {"create": 0, "destroy": 0, "failed": 0})
    seen_services = set()

    # Remove events older than EVENTS_WINDOW
    while events and events[0]["ts"] <= current_time - EVENTS_WINDOW:
        events.popleft()

    for event in events:
        action = event["action"]
        service_name = event["service_name"]
        if action in ("create", "destroy"):
            counts[service_name][action] += 1
            seen_services.add(service_name)
        elif action == "exec_die":
            if event["exit_code"] == "0":
                counts[service_name]["failed"] = 0
            else:
                seen_services.add(service_name)
                counts[service_name]["failed"] += 1

    for service_name, actions in counts.items():
        if not (
            actions["destroy"] >= EVENTS_THRESHOLD
            and actions["create"] >= EVENTS_THRESHOLD
        ):
            continue

        if service_name in pending_alerts:
            continue

        data = {
            "action": "create",
            "unique_id": calculate_md5(
                f"{SWARM_NAME} {service_name} {get_random_str(10)}"
            ),
            "message": f"{SWARM_NAME} service {service_name} failing on {HOSTNAME}",
            "summary": f"There were {actions["create"]} containers created and {actions["destroy"]} destroyed within {EVENTS_WINDOW} seconds.",
        }
        pending_alerts[service_name] = data
        send_alert(data)

    for service_name, actions in counts.items():
        if not actions["failed"] >= EVENTS_THRESHOLD:
            continue

        if service_name in pending_alerts:
            continue

        data = {
            "action": "create",
            "unique_id": calculate_md5(
                f"{SWARM_NAME} {service_name} {get_random_str(10)}"
            ),
            "message": f"{SWARM_NAME} service {service_name} failing healthcheck on {HOSTNAME}",
            "summary": f"There were {actions["failed"]} failed healthchecks within {EVENTS_WINDOW} seconds.",
        }
        pending_alerts[service_name] = data
        send_alert(data)

    for service_name in list(pending_alerts.keys()):
        if service_name in seen_services:
            continue

        data = {
            "action": "resolve",
            "unique_id": pending_alerts[service_name]["unique_id"],
            "message": f"{SWARM_NAME} service {service_name} stable on {HOSTNAME}",
            "summary": f"No events in last {EVENTS_WINDOW} seconds, assuming service is healthy (or stopped)",
        }
        del pending_alerts[service_name]
        send_alert(data)


def resolve_pending():
    while True:
        time.sleep(LOOP_SLEEP)
        with lock:
            process_events()


def main():
    try:
        resolving_thread = threading.Thread(target=resolve_pending, daemon=True)
        resolving_thread.start()

        for event in docker_events_stream():
            attrs = event["Actor"]["Attributes"]
            service_name = attrs.get("com.docker.swarm.service.name", None)
            if service_name is None:
                image = attrs.get("image")
                name = attrs.get("name")
                service_name = f"{image} {name}"

            data = {
                "ts": event["time"],
                "action": event["Action"],
                "service_name": service_name,
                "exit_code": attrs.get("exitCode", None),
            }

            # log_info(json.dumps(data))
            events.append(data)
            process_events()
    except requests.exceptions.RequestException as e:
        log_error(f"Error connecting to Docker API: {e}")


if __name__ == "__main__":
    main()
