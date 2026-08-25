#!/usr/bin/env python3
"""Minimal HTTP server that simulates ComfyUI or FileBrowser backend.
Handles WebSocket upgrade requests for testing."""
import argparse
import http.server
import socketserver
import sys

class MockBackendHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/ws":
            # Simulate WebSocket upgrade acceptance
            self.send_response(101)
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(f"<html><body>{self.server.backend_name}</body></html>".encode())

    def log_message(self, format, *args):
        # Quiet logs
        pass

class MockServer(socketserver.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--name", type=str, required=True)
    args = parser.parse_args()

    server = MockServer(("127.0.0.1", args.port), MockBackendHandler)
    server.backend_name = args.name
    print(f"Mock {args.name} listening on 127.0.0.1:{args.port}")
    server.serve_forever()