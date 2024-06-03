#!/usr/bin/env python3

import hashlib
import json
import os
import secrets
import string
import subprocess
import time
import threading
import urllib.parse as urlparse

from http.server import BaseHTTPRequestHandler, HTTPServer
from collections import defaultdict, deque
from logger import log_info, log_error

ALERT_SCRIPT = os.getenv("ALERT_SCRIPT", "jq .")
EVENTS_WINDOW = int(os.getenv("EVENTS_WINDOW", "300"))
EVENTS_THRESHOLD = int(os.getenv("EVENTS_THRESHOLD", "3"))
LOOP_SLEEP = int(os.getenv("LOOP_SLEEP", "10"))
SWARM_NAME = os.getenv("SWARM_NAME", "Swarm")

events = deque()
pending_alerts = {}
lock = threading.Lock()


def get_random_str(length):
    characters = string.ascii_letters + string.digits
    return "".join(secrets.choice(characters) for _ in range(length))


def process_events():
    current_time = time.time()

    counts = defaultdict(lambda: {"create": 0, "destroy": 0})
    hosts = defaultdict(set)
    seen_services = set()

    # Remove events older than EVENTS_WINDOW
    while events and events[0]["ts"] <= current_time - EVENTS_WINDOW:
        events.popleft()

    for event in events:
        counts[event["service_name"]][event["action"]] += 1
        hosts[event["service_name"]].add(event["host"])
        seen_services.add(event["service_name"])

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
            "message": f"{SWARM_NAME} service {service_name} not healthy",
            "summary": f"There were {actions["create"]} containers created and {actions["destroy"]} destroyed within {EVENTS_WINDOW} seconds.\nReported by {list(hosts[service_name])} host(s).",
        }
        pending_alerts[service_name] = data
        send_alert(data)

    for service_name in list(pending_alerts.keys()):
        if service_name in seen_services:
            continue

        data = {
            "action": "resolve",
            "unique_id": pending_alerts[service_name]["unique_id"],
            "message": f"{SWARM_NAME} service {service_name} is healthy",
            "summary": f"No events in last {EVENTS_WINDOW} seconds, assuming service is healthy (or stopped)",
        }
        del pending_alerts[service_name]
        send_alert(data)


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


def resolve_pending():
    while True:
        time.sleep(LOOP_SLEEP)
        with lock:
            process_events()


class EventHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse.urlparse(self.path)
        query = urlparse.parse_qs(parsed_path.query)
        payload = query.get("payload", [None])[0]
        if not payload:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"No payload received")
            return

        payload_data = json.loads(payload)
        host = payload_data["host"]
        timestamp = payload_data["ts"]
        action = payload_data["action"]
        service_name = payload_data["service_name"]

        with lock:
            events.append(
                {
                    "ts": timestamp,
                    "action": action,
                    "service_name": service_name,
                    "host": host,
                }
            )
            process_events()

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, format, *args):
        return


def main():
    try:
        cleanup_thread = threading.Thread(target=resolve_pending, daemon=True)
        cleanup_thread.start()

        server = HTTPServer(("0.0.0.0", 80), EventHandler)
        server.serve_forever()
    except Exception as e:
        log_error(f"{e}")


if __name__ == "__main__":
    main()
