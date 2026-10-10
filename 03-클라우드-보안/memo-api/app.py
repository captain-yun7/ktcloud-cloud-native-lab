import os
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        key = os.environ.get("API_KEY", "")
        body = f"memo api ok (key set: {bool(key)}, uid: {os.getuid()})\n".encode()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

HTTPServer(("0.0.0.0", 8000), H).serve_forever()
