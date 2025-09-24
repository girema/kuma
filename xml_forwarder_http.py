#!/usr/bin/env python3
"""
xml_forwarder_http.py
Listens on HTTP port 7070, receives POST requests with body containing events
separated by \0 (null byte), normalizes them and forwards each to DEST_HOST:DEST_PORT.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import socket
import logging
from logging.handlers import RotatingFileHandler
import time

# --- CONFIG ---
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 7070
DEST_HOST = "127.0.0.1"
DEST_PORT = 7071
SOCKET_TIMEOUT = 10
FORWARD_RETRIES = 3
FORWARD_RETRY_DELAY = 1.0
LOG_FILE = "/var/log/xml_forwarder/xml_forwarder_http.log"
LOG_MAX_BYTES = 10 * 1024 * 1024
LOG_BACKUPS = 5
# ----------------

# --- Logging ---
logger = logging.getLogger("xml_forwarder_http")
logger.setLevel(logging.INFO)
handler = RotatingFileHandler(LOG_FILE, maxBytes=LOG_MAX_BYTES, backupCount=LOG_BACKUPS)
formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


def normalize_event(text: str) -> str:
    """If the string is already one line — leave unchanged, otherwise remove newlines"""
    if '\n' not in text and '\r' not in text:
        return text.strip()
    return " ".join(text.replace('\r', '').split())


def forward_event(event: str):
    """Send one event to DEST_HOST:DEST_PORT"""
    to_forward = event + "\n"
    last_err = None
    for attempt in range(1, FORWARD_RETRIES + 1):
        try:
            with socket.create_connection((DEST_HOST, DEST_PORT), timeout=SOCKET_TIMEOUT) as s:
                s.sendall(to_forward.encode('utf-8'))
            logger.info("Forwarded event (len=%d)", len(to_forward))
            return True
        except Exception as e:
            last_err = e
            logger.warning("Forward attempt %d failed: %s", attempt, e)
            time.sleep(FORWARD_RETRY_DELAY)
    logger.error("Failed to forward event after %d attempts: %s", FORWARD_RETRIES, last_err)
    return False


class EventHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length <= 0:
                self.send_response(400)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"No body\n")
                return

            body = self.rfile.read(content_length)
            text = body.decode('utf-8', errors='replace')

            # Split events by \0
            events = text.split('\0')
            for ev in events:
                ev = ev.strip()
                if not ev:
                    continue
                one_line = normalize_event(ev)
                forward_event(one_line)

            # Always return OK
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK\n")

        except Exception as e:
            logger.exception("Error handling request: %s", e)
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Error\n")


def run():
    server = HTTPServer((LISTEN_HOST, LISTEN_PORT), EventHandler)
    logger.info("Starting HTTP XML forwarder on %s:%d -> %s:%d",
                LISTEN_HOST, LISTEN_PORT, DEST_HOST, DEST_PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Stopped by KeyboardInterrupt")
    finally:
        server.server_close()
        logger.info("Server stopped")


if __name__ == "__main__":
    run()
