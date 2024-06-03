import os
import sys
import logging
from datetime import datetime


def log(level, message):
    COLORS = {
        "INFO": "\033[36m",
        "WARNING": "\033[35m",
        "ERROR": "\033[31m",
        "DEFAULT": "\033[39m",
    }
    RESET = "\033[39m"

    color = COLORS.get(level, COLORS["DEFAULT"])
    timestamp = (
        datetime.now().strftime("%Y-%m-%d %H:%M:%S|")
        if int(os.getenv("LOGGER_USE_TS", "0"))
        else ""
    )

    if sys.stdout.isatty() or "CONTENT_TYPE" in os.environ:
        print(f"{color}-{level[0]}|{timestamp}{message}{RESET}", file=sys.stderr)
    else:
        print(f"-{level[0]}|{timestamp}{message}", file=sys.stderr)

    logging.basicConfig(format="%(message)s")

    if int(os.getenv("LOGGER_USE_SYSLOG", "0")):
        syslog = logging.getLogger()
        syslog.setLevel(logging.INFO)
        if level == "ERROR":
            syslog.error(f"{level} - {message}")
        elif level == "WARNING":
            syslog.warning(f"{level} - {message}")
        else:
            syslog.info(f"{level} - {message}")


def log_info(message):
    log("INFO", message)


def log_warn(message):
    log("WARNING", message)


def log_error(message):
    log("ERROR", message)
