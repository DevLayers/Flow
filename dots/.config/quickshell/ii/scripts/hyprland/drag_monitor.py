#!/usr/bin/env python3
"""Window drag/resize detector for the tiling assistant.

Hyprland has no IPC event for "the user is dragging a window", so this watches
for one in two complementary ways:

  1. Companion keybinds.  `SUPER + mouse:272` / `SUPER + mouse:273` also fire a
     Quickshell global shortcut, and the shell forwards press/release here as a
     hint.  Exact, but only covers Hyprland's own drag binds.
  2. A motion heuristic.  Client-side-decoration titlebar drags (GTK/Qt apps)
     never touch a keybind, so the active window's geometry is sampled and a
     drag is inferred when the window tracks the cursor.  Ends on quiescence,
     since nothing tells us when the button comes back up.

Output is newline-delimited JSON on stdout:

    {"event": "ready"}
    {"event": "gaps", "outer": 5, "inner": 4}
    {"event": "dragStart", "kind": "move"|"resize", "source": "keybind"|"motion",
     "address": "0x...", "x": 100, "y": 200,
     "window": {"x": .., "y": .., "width": .., "height": .., "floating": bool,
                "monitor": 0, "workspace": 1},
     "before": {...}}   # same shape, sampled just before the drag began
    {"event": "dragMove", "x": 100, "y": 200}
    {"event": "dragEnd", "kind": "move", "source": "motion", "x": 100, "y": 200,
     "window": {...}}   # geometry the gesture ended with, for co-resize

Input is newline-delimited JSON on stdin:

    {"cmd": "hint", "kind": "move"|"resize", "state": "down"|"up"}
    {"cmd": "config", "idleHz": 30, "activeHz": 90, "tolerance": 2,
     "motion": true, "keybinds": true}
    {"cmd": "suppress", "ms": 300}   # ignore geometry we changed ourselves
    {"cmd": "quit"}

Coordinates are Hyprland's global logical pixels, matching `hyprctl cursorpos`.
"""

import json
import os
import select
import socket
import sys
import time

# A motion-detected drag has no release event, so it ends once the window and
# the cursor have both been still for this long.
MOTION_END_MS = 350
# Never spend longer than this blocked in select(), so stdin stays responsive
# even when polling is idle.
MAX_WAIT_S = 0.25
# How long an idle window sample may go unrefreshed while the pointer is still.
WINDOW_REFRESH_S = 1.0


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(message):
    sys.stderr.write("[drag_monitor] %s\n" % message)
    sys.stderr.flush()


def socket_dir():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        return None
    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    for base in ("%s/hypr/%s" % (runtime, signature), "/tmp/hypr/%s" % signature):
        if os.path.isdir(base):
            return base
    return None


class Hyprctl:
    """One-shot request socket. Hyprland closes it after every reply."""

    def __init__(self, directory):
        self.path = os.path.join(directory, ".socket.sock")

    def request(self, command):
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(0.5)
            sock.connect(self.path)
            sock.sendall(command.encode())
            chunks = []
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                chunks.append(chunk)
            sock.close()
            return b"".join(chunks).decode(errors="replace")
        except OSError:
            return None

    def json(self, command):
        raw = self.request("j/" + command)
        if not raw:
            return None
        try:
            return json.loads(raw)
        except ValueError:
            return None

    def cursorpos(self):
        raw = self.request("/cursorpos")
        if not raw:
            return None
        parts = raw.strip().split(",")
        if len(parts) != 2:
            return None
        try:
            return (int(parts[0]), int(parts[1]))
        except ValueError:
            return None


def first_css_value(css, fallback):
    """Hyprland reports gap options as a CSS-ish string: "5 5 5 5"."""
    if not isinstance(css, str):
        return fallback
    for token in css.replace(",", " ").split():
        try:
            return int(float(token))
        except ValueError:
            continue
    return fallback


def read_gaps(ctl):
    out = ctl.json("getoption general:gaps_out") or {}
    inn = ctl.json("getoption general:gaps_in") or {}
    return {
        "event": "gaps",
        "outer": first_css_value(out.get("css"), 5),
        "inner": first_css_value(inn.get("css"), 4),
    }


def window_sample(ctl):
    win = ctl.json("activewindow")
    if not isinstance(win, dict) or not win.get("address"):
        return None
    at = win.get("at") or [0, 0]
    size = win.get("size") or [0, 0]
    workspace = win.get("workspace") or {}
    return {
        "address": win.get("address"),
        "x": at[0],
        "y": at[1],
        "width": size[0],
        "height": size[1],
        "floating": bool(win.get("floating")),
        "monitor": win.get("monitor", -1),
        "workspace": workspace.get("id", -1),
        "fullscreen": bool(win.get("fullscreen")),
    }


class Monitor:
    def __init__(self, ctl):
        self.ctl = ctl
        self.idle_interval = 1.0 / 30.0
        self.active_interval = 1.0 / 90.0
        self.tolerance = 2
        self.use_motion = True
        self.use_keybinds = True

        self.dragging = False
        self.kind = ""
        self.source = ""
        self.cursor = None
        self.window = None
        self.window_time = 0.0
        self.suppress_until = 0.0
        self.last_change = 0.0

    # -- configuration ------------------------------------------------------

    def configure(self, cmd):
        idle_hz = float(cmd.get("idleHz", 30) or 30)
        active_hz = float(cmd.get("activeHz", 90) or 90)
        self.idle_interval = 1.0 / max(1.0, min(idle_hz, 240.0))
        self.active_interval = 1.0 / max(1.0, min(active_hz, 240.0))
        self.tolerance = max(0, int(cmd.get("tolerance", 2) or 0))
        self.use_motion = bool(cmd.get("motion", True))
        self.use_keybinds = bool(cmd.get("keybinds", True))

    @property
    def interval(self):
        return self.active_interval if self.dragging else self.idle_interval

    # -- drag lifecycle -----------------------------------------------------

    def start(self, kind, source, cursor, window, before=None):
        self.dragging = True
        self.kind = kind
        self.source = source
        self.cursor = cursor
        self.window = window
        self.last_change = time.monotonic()
        if not before or before.get("address") != window["address"]:
            before = window
        emit({
            "event": "dragStart",
            "kind": kind,
            "source": source,
            "address": window["address"],
            "x": cursor[0],
            "y": cursor[1],
            "window": window,
            # Hyprland floats and re-centres a tiled window the moment a drag
            # begins, so restoring it later needs the sample taken just before.
            "before": before,
        })

    def stop(self):
        if not self.dragging:
            return
        cursor = self.cursor or (0, 0)
        # Geometry as the gesture ends, which is what tells the shell which edge
        # a resize moved. Sampled fresh: the polled one is a frame behind, and a
        # keybind drag never polls the window at all.
        window = window_sample(self.ctl)
        if self.window and (not window or window["address"] != self.window["address"]):
            window = self.window
        emit({
            "event": "dragEnd",
            "kind": self.kind,
            "source": self.source,
            "x": cursor[0],
            "y": cursor[1],
            "window": window,
        })
        self.dragging = False
        self.kind = ""
        self.source = ""

    def hint(self, cmd):
        if not self.use_keybinds:
            return
        kind = "resize" if cmd.get("kind") == "resize" else "move"
        if cmd.get("state") == "up":
            # Only the gesture that opened the drag may close it, otherwise the
            # move bind's release would cancel a resize that started later.
            if self.dragging and self.source == "keybind" and self.kind == kind:
                self.poll_cursor()
                self.stop()
            return
        if self.dragging:
            return
        # Sampled before the request below, which already sees the dragged window.
        before = self.window
        cursor = self.ctl.cursorpos()
        window = window_sample(self.ctl)
        if cursor is None or window is None or window["fullscreen"]:
            return
        self.start(kind, "keybind", cursor, window, before)

    def suppress(self, cmd):
        try:
            ms = float(cmd.get("ms", 300))
        except (TypeError, ValueError):
            ms = 300.0
        self.suppress_until = time.monotonic() + max(0.0, ms) / 1000.0

    # -- polling ------------------------------------------------------------

    def poll_cursor(self):
        cursor = self.ctl.cursorpos()
        if cursor is None or cursor == self.cursor:
            return False
        self.cursor = cursor
        return True

    def poll_dragging(self):
        if self.poll_cursor():
            self.last_change = time.monotonic()
            emit({"event": "dragMove", "x": self.cursor[0], "y": self.cursor[1]})
        if self.source != "motion":
            return
        window = window_sample(self.ctl)
        if window and window["address"] == self.window["address"]:
            if self.moved(self.window, window):
                self.last_change = time.monotonic()
            self.window = window
        if (time.monotonic() - self.last_change) * 1000.0 >= MOTION_END_MS:
            self.stop()

    def moved(self, before, after):
        tol = self.tolerance
        return (abs(after["x"] - before["x"]) > tol or abs(after["y"] - before["y"]) > tol
                or abs(after["width"] - before["width"]) > tol
                or abs(after["height"] - before["height"]) > tol)

    def poll_idle(self):
        cursor = self.ctl.cursorpos()
        if cursor is None:
            return
        previous_cursor = self.cursor
        self.cursor = cursor
        now = time.monotonic()

        # No drag moves a window without moving the pointer, so a pointer that
        # has not budged needs no window query. That is what keeps idling cheap,
        # but the last sample is still refreshed now and then so that a drag
        # started without moving the mouse first has something recent to restore.
        stale = (now - self.window_time) > WINDOW_REFRESH_S
        if previous_cursor is not None and cursor == previous_cursor and not stale:
            return

        window = window_sample(self.ctl)
        previous_window = self.window
        self.window = window
        self.window_time = now
        if not self.use_motion or window is None:
            return
        if now < self.suppress_until:
            return
        if previous_window is None or previous_cursor is None:
            return
        if previous_window["address"] != window["address"] or window["fullscreen"]:
            return

        dx, dy = window["x"] - previous_window["x"], window["y"] - previous_window["y"]
        dw, dh = window["width"] - previous_window["width"], window["height"] - previous_window["height"]
        cdx, cdy = cursor[0] - previous_cursor[0], cursor[1] - previous_cursor[1]
        tol = self.tolerance
        cursor_moved = abs(cdx) > tol or abs(cdy) > tol

        if abs(dw) > tol or abs(dh) > tol:
            # A window that changes size while the pointer travels is being
            # resized by its border; one that resizes on its own is not.
            if cursor_moved:
                self.start("resize", "motion", cursor, window, previous_window)
            return

        if abs(dx) <= tol and abs(dy) <= tol:
            return
        # A dragged window tracks the pointer one-to-one. Anything else moving
        # it - an animation, a layout change, a script - does not.
        slack = max(tol, 3)
        if abs(dx - cdx) <= slack and abs(dy - cdy) <= slack and cursor_moved:
            self.start("move", "motion", cursor, window, previous_window)

    def poll(self):
        if self.dragging:
            self.poll_dragging()
        else:
            self.poll_idle()


def main():
    directory = socket_dir()
    if directory is None:
        log("no Hyprland instance found")
        return 1

    ctl = Hyprctl(directory)
    monitor = Monitor(ctl)

    events = None
    try:
        events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        events.connect(os.path.join(directory, ".socket2.sock"))
        events.setblocking(False)
    except OSError:
        events = None
        log("event socket unavailable, gaps will not follow config reloads")

    emit({"event": "ready"})
    emit(read_gaps(ctl))

    stdin = sys.stdin
    buffered = b""
    next_poll = time.monotonic()

    while True:
        watched = [stdin] + ([events] if events else [])
        timeout = max(0.0, min(next_poll - time.monotonic(), MAX_WAIT_S))
        try:
            readable, _, _ = select.select(watched, [], [], timeout)
        except (OSError, ValueError):
            return 1

        if stdin in readable:
            line = stdin.readline()
            if not line:
                return 0
            try:
                cmd = json.loads(line)
            except ValueError:
                cmd = None
            if isinstance(cmd, dict):
                name = cmd.get("cmd")
                if name == "quit":
                    return 0
                elif name == "hint":
                    monitor.hint(cmd)
                elif name == "config":
                    monitor.configure(cmd)
                elif name == "suppress":
                    monitor.suppress(cmd)

        if events and events in readable:
            try:
                chunk = events.recv(8192)
            except OSError:
                chunk = b""
            if not chunk:
                events.close()
                events = None
            else:
                buffered += chunk
                lines = buffered.split(b"\n")
                buffered = lines.pop()
                for raw in lines:
                    if raw.startswith(b"configreloaded"):
                        emit(read_gaps(ctl))

        now = time.monotonic()
        if now >= next_poll:
            monitor.poll()
            # Recomputed after polling: the interval changes when a drag starts.
            next_poll = max(now + monitor.interval, next_poll + monitor.interval)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except BrokenPipeError:
        sys.exit(0)
