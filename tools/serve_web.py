#!/usr/bin/env python3
"""Serves build/web for TestSprite runs, gzip-compressed and multi-threaded.

Python's plain http.server sends files uncompressed, so the 2.6 MB Flutter
bundle was too slow through the TestSprite tunnel. This server compresses
text-like assets once, keeps them in memory, and serves requests in parallel.

    python3 -I tools/serve_web.py [port]
"""

import gzip
import http.server
import mimetypes
import os
import sys
import threading

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))
COMPRESS = {".js", ".mjs", ".json", ".html", ".css", ".ttf", ".otf", ".wasm", ".svg", ".txt", ".frag"}
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".mjs")

_cache = {}
_lock = threading.Lock()


def _load(path):
    """Returns (raw bytes, gzipped bytes or None, mtime), cached by mtime."""
    mtime = os.path.getmtime(path)
    with _lock:
        hit = _cache.get(path)
        if hit and hit[2] == mtime:
            return hit
    with open(path, "rb") as f:
        raw = f.read()
    gz = gzip.compress(raw, 6) if os.path.splitext(path)[1] in COMPRESS else None
    entry = (raw, gz, mtime)
    with _lock:
        _cache[path] = entry
    return entry


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_HEAD(self):
        self._serve(head=True)

    def do_GET(self):
        self._serve(head=False)

    def _serve(self, head):
        rel = self.path.split("?", 1)[0].split("#", 1)[0].lstrip("/") or "index.html"
        path = os.path.realpath(os.path.join(ROOT, rel))
        if not path.startswith(ROOT + os.sep) and path != ROOT:
            return self._error(403)
        if os.path.isdir(path):
            path = os.path.join(path, "index.html")
        if not os.path.isfile(path):
            # Single-page app: unknown paths fall back to index.html.
            path = os.path.join(ROOT, "index.html")
        raw, gz, _ = _load(path)
        use_gz = gz is not None and "gzip" in self.headers.get("Accept-Encoding", "")
        body = gz if use_gz else raw
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(path)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        if use_gz:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        if not head:
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # client went away; nothing to do

    def _error(self, code):
        self.send_response(code)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    if not os.path.isfile(os.path.join(ROOT, "index.html")):
        sys.exit(f"No build at {ROOT}. Run: flutter build web --release --dart-define=DOD_TEST_MODE=true")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Serving {ROOT} on http://127.0.0.1:{port} (gzip on)", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
