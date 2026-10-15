#!/usr/bin/env python3
"""DLP 日志接收端：iPhone 插件 POST 日志到这里，助手直接读 uploads/ 目录。
只监听 127.0.0.1:18800，对外靠 cloudflared 隧道暴露。
鉴权：请求头 X-DLP-Token 必须等于 .token 文件内容。
"""
import http.server
import os
import secrets
import time

BASE = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE, "uploads")
TOKEN_FILE = os.path.join(BASE, ".token")
PORT = 18800
MAX_BODY = 2 * 1024 * 1024  # 2MB

os.makedirs(UPLOAD_DIR, exist_ok=True)
if not os.path.exists(TOKEN_FILE):
    with open(TOKEN_FILE, "w") as f:
        f.write(secrets.token_hex(16))
    os.chmod(TOKEN_FILE, 0o600)
with open(TOKEN_FILE) as f:
    TOKEN = f.read().strip()


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "DLPReceiver/1.0"

    def _send(self, code, body=b""):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, b"ok")
        else:
            self._send(404)

    def do_POST(self):
        if self.path != "/upload":
            self._send(404)
            return
        if self.headers.get("X-DLP-Token") != TOKEN:
            self._send(403)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY:
            self._send(413)
            return
        body = self.rfile.read(length)
        name = time.strftime("%Y%m%d_%H%M%S") + "_" + secrets.token_hex(4) + ".log"
        path = os.path.join(UPLOAD_DIR, name)
        with open(path, "wb") as f:
            f.write(body)
        print(f"saved {name} ({len(body)} bytes)", flush=True)
        self._send(200, b"saved")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"listening on 127.0.0.1:{PORT}", flush=True)
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
