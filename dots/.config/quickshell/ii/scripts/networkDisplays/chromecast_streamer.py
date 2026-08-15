#!/usr/bin/env python3
"""
Native Wayland/Hyprland Screen Casting to Google Cast / Chromecast / Android TV
Encodes desktop using GStreamer/wf-recorder (libx264, I420/yuv420p, zero latency, ISO fragmented MP4)
and serves it over a lightweight HTTP stream to pychromecast.
"""

import sys
import os
import time
import socket
import signal
import argparse
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

PID_FILE = os.path.expanduser("~/.cache/network_display_cast.pid")
HTTP_PORT = 8092

def get_local_ip_for_target(target_ip: str) -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect((target_ip, 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return "127.0.0.1"

class StreamBuffer:
    def __init__(self):
        self.clients = []
        self.lock = threading.Lock()
        self.running = True
        self.header = b""

    def register(self, client):
        with self.lock:
            self.clients.append(client)
            if self.header:
                try:
                    client.wfile.write(self.header)
                    client.wfile.flush()
                except Exception:
                    pass

    def unregister(self, client):
        with self.lock:
            if client in self.clients:
                self.clients.remove(client)

    def broadcast(self, chunk: bytes):
        with self.lock:
            if not self.header and len(chunk) >= 8:
                self.header = chunk[:64]
            to_remove = []
            for client in self.clients:
                try:
                    client.wfile.write(chunk)
                    client.wfile.flush()
                except Exception:
                    to_remove.append(client)
            for c in to_remove:
                self.clients.remove(c)

stream_buffer = StreamBuffer()

class CastHTTPHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress request logging

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Connection", "close")
        self.end_headers()

        stream_buffer.register(self)
        try:
            while stream_buffer.running:
                time.sleep(0.2)
        except Exception:
            pass
        finally:
            stream_buffer.unregister(self)

def run_http_server(port: int):
    server = HTTPServer(("0.0.0.0", port), CastHTTPHandler)
    server.serve_forever()

def start_casting(target_ip: str, target_port: int, monitor_name: str = ""):
    local_ip = get_local_ip_for_target(target_ip)
    stream_url = f"http://{local_ip}:{HTTP_PORT}/live.mp4"

    # Start HTTP server thread
    http_thread = threading.Thread(target=run_http_server, args=(HTTP_PORT,), daemon=True)
    http_thread.start()

    # Try gst-launch-1.0 with pipewiresrc and fragmented streamable mp4mux
    cmd = [
        "gst-launch-1.0", "-q",
        "pipewiresrc", "do-timestamp=true",
        "!", "videoconvert",
        "!", "video/x-raw,format=I420",
        "!", "x264enc", "tune=zerolatency", "speed-preset=ultrafast", "bitrate=6000", "key-int-max=30",
        "!", "h264parse",
        "!", "mp4mux", "fragment-duration=500", "streamable=true",
        "!", "fdsink", "fd=1"
    ]

    try:
        recorder = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=65536
        )
    except Exception:
        # Fallback to wf-recorder
        fallback_cmd = [
            "wf-recorder",
            "-c", "libx264",
            "-x", "yuv420p",
            "-p", "preset=ultrafast",
            "-p", "tune=zerolatency",
            "-p", "bframes=0",
            "-p", "keyint=30",
            "-p", "crf=23",
            "-m", "matroska",
            "-f", "-"
        ]
        if monitor_name:
            fallback_cmd.extend(["-o", monitor_name])
        recorder = subprocess.Popen(
            fallback_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=65536
        )

    # Save PID
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(f"{os.getpid()}:{recorder.pid}:{target_ip}:{target_port}")

    # Reader thread
    def read_stream():
        while stream_buffer.running and recorder.poll() is None:
            chunk = recorder.stdout.read(16384)
            if not chunk:
                break
            stream_buffer.broadcast(chunk)

    reader_thread = threading.Thread(target=read_stream, daemon=True)
    reader_thread.start()

    # Connect pychromecast
    try:
        import pychromecast
        cast = pychromecast.get_chromecast_from_host((target_ip, target_port, None, None, None))
        cast.wait(timeout=10)
        cast.media_controller.play_media(stream_url, content_type="video/mp4", stream_type="LIVE")
        cast.media_controller.block_until_active(timeout=10)
    except Exception as e:
        sys.stderr.write(f"[chromecast_streamer] pychromecast error: {e}\n")

    def handle_signal(sig, frame):
        stream_buffer.running = False
        if recorder.poll() is None:
            recorder.terminate()
        try:
            if 'cast' in locals():
                cast.quit_app()
        except Exception:
            pass
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    while stream_buffer.running and recorder.poll() is None:
        time.sleep(1)

def stop_casting():
    if not os.path.exists(PID_FILE):
        return
    try:
        with open(PID_FILE, "r") as f:
            parts = f.read().strip().split(":")
            if len(parts) >= 2:
                main_pid = int(parts[0])
                rec_pid = int(parts[1])
                try:
                    os.kill(rec_pid, signal.SIGTERM)
                except Exception:
                    pass
                try:
                    os.kill(main_pid, signal.SIGTERM)
                except Exception:
                    pass
            if len(parts) >= 4:
                target_ip = parts[2]
                target_port = int(parts[3])
                try:
                    import pychromecast
                    cast = pychromecast.get_chromecast_from_host((target_ip, target_port, None, None, None))
                    cast.wait(timeout=3)
                    cast.quit_app()
                except Exception:
                    pass
    except Exception:
        pass
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["start", "stop", "status"])
    parser.add_argument("--ip", default="")
    parser.add_argument("--port", type=int, default=8009)
    parser.add_argument("--monitor", default="")
    args = parser.parse_args()

    if args.action == "start":
        if not args.ip:
            sys.stderr.write("Missing --ip\n")
            sys.exit(1)
        start_casting(args.ip, args.port, args.monitor)
    elif args.action == "stop":
        stop_casting()
    elif args.action == "status":
        if os.path.exists(PID_FILE):
            print("active")
        else:
            print("idle")
