#!/usr/bin/env python3
"""Local studio server for the murmuration animation.

Serves this directory, and exposes an /export endpoint that runs the existing
render-gif.sh pipeline with whatever parameters the page is currently showing.
Rendering takes minutes, so export starts a background job and the page polls
/job/<id> for progress.
"""
import http.server
import json
import os
import re
import shutil
import socketserver
import subprocess
import tempfile
import threading
import time
import uuid

# Served tree. Kept explicit because the launcher runs this script from
# /tmp (macOS blocks it from opening scripts under ~/Desktop), while the
# animation and its layers live in the project folder.
ROOT = os.environ.get("STUDIO_ROOT",
    "/Users/marrasherrier/Desktop/claude/investor deck animations")
PORT = 3477

JOBS = {}
JOBS_LOCK = threading.Lock()


def set_job(jid, **kw):
    with JOBS_LOCK:
        JOBS.setdefault(jid, {}).update(kw)


def run_export(jid, query, fps, dur, fmt, name):
    """Render one or both formats, sharing a single frame capture."""
    frames = tempfile.mkdtemp(prefix="murm-frames-")
    try:
        exts = {"gif": ["gif"], "mp4": ["mp4"], "both": ["mp4", "gif"]}[fmt]
        total_frames = max(1, round(float(fps) * float(dur)))
        set_job(jid, state="rendering", total=total_frames, frame=0,
                message="starting Chrome…", outputs=[])

        env = dict(os.environ,
                   W="995", H="1066", SCALE="1",
                   FPS=str(fps), DUR=str(dur), BG="#060606",
                   FRAMES_DIR=frames,
                   URLEXTRA="&ui=0&" + query.lstrip("&?"))

        outputs = []
        for i, ext in enumerate(exts):
            out = f"{name}.{ext}"
            set_job(jid, message=f"encoding {ext.upper()} ({i+1}/{len(exts)})…")
            proc = subprocess.Popen(
                ["./render-gif.sh", "house-animation-murmuration.html", out],
                cwd=ROOT, env=env, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, bufsize=1)
            # render-gif.sh reports "frame N/M" on a \r-updated line
            buf = ""
            while True:
                ch = proc.stdout.read(1)
                if not ch:
                    break
                if ch in "\r\n":
                    m = re.search(r"frame (\d+)/(\d+)", buf)
                    if m:
                        set_job(jid, frame=int(m.group(1)), total=int(m.group(2)),
                                message=f"capturing frames ({ext.upper()})")
                    elif "Assembling" in buf or "Encoding" in buf:
                        set_job(jid, message=f"encoding {ext.upper()}…")
                    buf = ""
                else:
                    buf += ch
            proc.wait()
            path = os.path.join(ROOT, out)
            if proc.returncode != 0 or not os.path.exists(path):
                set_job(jid, state="error",
                        message=f"{ext.upper()} render failed (exit {proc.returncode})")
                return
            outputs.append({"file": out, "bytes": os.path.getsize(path)})
            set_job(jid, outputs=list(outputs))

        # drop a sidecar so a rendered file always has its settings on record
        with open(os.path.join(ROOT, f"{name}.params.json"), "w") as f:
            json.dump({"query": query, "fps": fps, "dur": dur,
                       "rendered": time.strftime("%Y-%m-%d %H:%M:%S")}, f, indent=2)
        set_job(jid, state="done", message="saved", outputs=outputs)
    except Exception as exc:                       # noqa: BLE001 - report to the UI
        set_job(jid, state="error", message=str(exc))
    finally:
        shutil.rmtree(frames, ignore_errors=True)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def log_message(self, fmt, *args):
        if "/job/" not in self.path:                # polling would drown the log
            super().log_message(fmt, *args)

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/job/"):
            jid = self.path[5:]
            with JOBS_LOCK:
                job = dict(JOBS.get(jid, {"state": "unknown"}))
            return self._json(200, job)
        if self.path == "/" or self.path.startswith("/?"):
            self.path = "/house-animation-murmuration.html" + self.path[1:]
        return super().do_GET()

    def do_POST(self):
        if self.path != "/export":
            return self._json(404, {"error": "not found"})
        n = int(self.headers.get("Content-Length", 0))
        try:
            req = json.loads(self.rfile.read(n) or b"{}")
        except json.JSONDecodeError:
            return self._json(400, {"error": "bad json"})

        name = re.sub(r"[^A-Za-z0-9._-]", "-", req.get("name") or "murmuration-export")
        fmt = req.get("format", "both")
        if fmt not in ("gif", "mp4", "both"):
            fmt = "both"
        try:
            fps = max(5, min(30, int(req.get("fps", 25))))
            dur = max(0.5, min(30.0, float(req.get("dur", 12.0))))
        except (TypeError, ValueError):
            return self._json(400, {"error": "bad fps/dur"})

        jid = uuid.uuid4().hex[:10]
        set_job(jid, state="queued", message="queued", frame=0, total=1, outputs=[])
        threading.Thread(target=run_export,
                         args=(jid, req.get("query", ""), fps, dur, fmt, name),
                         daemon=True).start()
        return self._json(200, {"job": jid})


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    os.chdir(ROOT)
    with Server(("127.0.0.1", PORT), Handler) as httpd:
        print(f"murmuration studio on http://127.0.0.1:{PORT}/")
        httpd.serve_forever()
