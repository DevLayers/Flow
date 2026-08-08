#!/usr/bin/env python3
"""Window drag/resize detector for the tiling assistant.

Hyprland has no IPC event for "the user is dragging a window", so this leans on
companion keybinds instead: `SUPER + mouse:272` / `SUPER + mouse:273` also fire a
Quickshell global shortcut, and the shell forwards press and release here as a
hint.  That covers Hyprland's own drag binds, and nothing else.

Client-side-decoration titlebar drags (GTK/Qt apps) fire no bind, and an earlier
version of this script inferred them by watching the active window track the
cursor.  That was removed, because nothing announces the button coming back up:
the drag had to be guessed as over, and guessing early meant the shell floated
and repositioned a window Hyprland still held in an interactive move, which left
the layout tree inconsistent until the layout was reset.  Guessing late meant no
overlay at all.  A gesture nobody reports the end of cannot be handled safely,
so only the binds are trusted now.

Output is newline-delimited JSON on stdout:

    {"event": "ready"}
    {"event": "gaps", "outer": 5, "inner": 4}
    {"event": "dragStart", "kind": "move"|"resize",
     "address": "0x...", "x": 100, "y": 200,
     "window": {"x": .., "y": .., "width": .., "height": .., "floating": bool,
                "monitor": 0, "workspace": 1},
     "before": {...}}   # same shape, sampled just before the drag began
    {"event": "dragMove", "x": 100, "y": 200}
    {"event": "dragEnd", "kind": "move", "x": 100, "y": 200,
     "cancelled": false,   # true when Hyprland dropped the gesture, not the user
     "window": {...}}   # geometry the gesture ended with, for co-resize

Input is newline-delimited JSON on stdin:

    {"cmd": "hint", "kind": "move"|"resize", "state": "down"|"up"}
    {"cmd": "config", "idleHz": 5, "activeHz": 90, "tolerance": 2,
     "keybinds": true}
    {"cmd": "quit"}

Coordinates are Hyprland's global logical pixels, matching `hyprctl cursorpos`.
"""

import json
import os
import select
import socket
import sys
import time

# Never spend longer than this blocked in select(), so stdin stays responsive
# even when polling is idle.
MAX_WAIT_S = 0.25

# A gesture Hyprland dropped without telling anyone looks, from here, like a
# window sitting exactly where it started. So does a drag that has only just
# begun, and a tiled one Hyprland will not move until it swaps on release, so
# the two are told apart by how long the window stays put.
STALE_DRAG_S = 2.0

# Once the window is following the cursor, it stopping while the cursor keeps
# going is the gesture being let go, and there is no ambiguity left to wait out.
# Long enough that a frame or two of lag between the two samples cannot pass for
# it, short enough that the drop still feels like one.
STALE_FOLLOW_S = 0.15

# Backstop for anything the checks below still miss: no gesture is a minute
# long, and an overlay that never goes away is worse than one that goes away
# early.
MAX_DRAG_S = 60.0


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

    def json_batch(self, *commands):
        """Answer several queries over one connection.

        Hyprland runs a `[[BATCH]]` request's commands in order and concatenates
        their replies, so they are decoded one after another from the same
        string. Worth it because the connection, not the query, is the cost.
        """
        raw = self.request("[[BATCH]]" + ";".join("j/" + c for c in commands))
        results = []
        if raw:
            decoder = json.JSONDecoder()
            index = 0
            for _ in commands:
                while index < len(raw) and raw[index].isspace():
                    index += 1
                try:
                    value, index = decoder.raw_decode(raw, index)
                except ValueError:
                    # Everything after a reply we could not read is at an
                    # unknown offset, so the rest of the batch is given up on.
                    break
                results.append(value)
        return results + [None] * (len(commands) - len(results))

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

    def sample(self):
        """Cursor position and active window, in a single round trip."""
        cursor, window = self.json_batch("cursorpos", "activewindow")
        return shape_cursor(cursor), shape_window(window)


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


def shape_cursor(pos):
    if not isinstance(pos, dict):
        return None
    try:
        return (int(pos["x"]), int(pos["y"]))
    except (KeyError, TypeError, ValueError):
        return None


def shape_window(win):
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


def window_sample(ctl):
    return shape_window(ctl.json("activewindow"))


def same_address(one, other):
    """Event addresses come without the `0x` that the JSON replies carry."""
    if not one or not other:
        return False
    return one.lower().lstrip("0x") == other.lower().lstrip("0x")


def shifted(before, after):
    """Whether two consecutive samples of the same window differ at all. No
    tolerance, unlike the comparison against the pre-drag geometry: Hyprland
    reports whole pixels and there is no noise to absorb between two polls, so
    anything else would read a slow drag as a stopped one."""
    return (after["x"] != before["x"] or after["y"] != before["y"]
            or after["width"] != before["width"] or after["height"] != before["height"])


class Monitor:
    def __init__(self, ctl):
        self.ctl = ctl
        self.idle_interval = 1.0 / 5.0
        self.active_interval = 1.0 / 90.0
        self.tolerance = 2
        self.use_keybinds = True

        self.dragging = False
        self.kind = ""
        self.cursor = None
        self.window = None
        # Geometry the dragged window had before the gesture, and whether it
        # has left it at any point since - a window back at a place it once
        # left was put there by Hyprland dropping the gesture.
        self.before = None
        self.left_origin = False
        # When the gesture began, and since when the window has had nothing to
        # say about whether it is still held.
        self.started_at = 0.0
        self.settled_at = None

    # -- configuration ------------------------------------------------------

    def configure(self, cmd):
        idle_hz = float(cmd.get("idleHz", 5) or 5)
        active_hz = float(cmd.get("activeHz", 90) or 90)
        self.idle_interval = 1.0 / max(1.0, min(idle_hz, 240.0))
        self.active_interval = 1.0 / max(1.0, min(active_hz, 240.0))
        self.tolerance = max(0, int(cmd.get("tolerance", 2) or 0))
        self.use_keybinds = bool(cmd.get("keybinds", True))

    @property
    def interval(self):
        # Nothing to watch for between gestures: the window is sampled only so
        # that a drag starting now has a pre-drag geometry to restore to.
        return self.active_interval if self.dragging else self.idle_interval

    # -- drag lifecycle -----------------------------------------------------

    def start(self, kind, cursor, window, before=None):
        self.dragging = True
        self.kind = kind
        self.cursor = cursor
        self.window = window
        self.left_origin = False
        self.started_at = time.monotonic()
        self.settled_at = None
        if not before or before.get("address") != window["address"]:
            before = window
        self.before = before
        emit({
            "event": "dragStart",
            "kind": kind,
            "address": window["address"],
            "x": cursor[0],
            "y": cursor[1],
            "window": window,
            # Hyprland floats and re-centres a tiled window the moment a drag
            # begins, so restoring it later needs the sample taken just before.
            "before": before,
        })

    def stop(self, cancelled=False):
        if not self.dragging:
            return
        cursor = self.cursor or (0, 0)
        # Geometry as the gesture ends, which is what tells the shell which edge
        # a resize moved. Sampled fresh, because the polled one is a frame behind.
        window = window_sample(self.ctl)
        if self.window and (not window or window["address"] != self.window["address"]):
            window = self.window
        emit({
            "event": "dragEnd",
            "kind": self.kind,
            "x": cursor[0],
            "y": cursor[1],
            # Hyprland puts the window back where it found it when it drops a
            # gesture, so there is nothing to tile: the shell only has to stop
            # showing the overlay.
            "cancelled": cancelled,
            "window": window,
        })
        self.dragging = False
        self.kind = ""
        self.before = None
        self.left_origin = False
        self.settled_at = None

    def hint(self, cmd):
        if not self.use_keybinds:
            return
        kind = "resize" if cmd.get("kind") == "resize" else "move"
        if cmd.get("state") == "up":
            # Only the gesture that opened the drag may close it, otherwise the
            # move bind's release would cancel a resize that started later.
            if self.dragging and self.kind == kind:
                self.poll_cursor()
                self.stop()
            return
        if self.dragging:
            return
        # Sampled before the request below, which already sees the dragged window.
        before = self.window
        cursor, window = self.ctl.sample()
        if cursor is None or window is None or window["fullscreen"]:
            return
        self.start(kind, cursor, window, before)

    # -- polling ------------------------------------------------------------

    def poll_cursor(self):
        cursor = self.ctl.cursorpos()
        if cursor is None or cursor == self.cursor:
            return False
        self.cursor = cursor
        return True

    def poll_dragging(self):
        cursor, window = self.ctl.sample()
        cursor_moved = cursor is not None and cursor != self.cursor
        if cursor_moved:
            self.cursor = cursor
            emit({"event": "dragMove", "x": cursor[0], "y": cursor[1]})
        if time.monotonic() - self.started_at > MAX_DRAG_S:
            self.stop(cancelled=True)
            return
        self.poll_keybind_drag(window, cursor_moved)

    def poll_keybind_drag(self, window, cursor_moved):
        """Hyprland ends a gesture the instant its modifier goes up, and it
        neither fires the bind's release nor lets the modifier's own release
        bind through while it owns the pointer, so nothing announces it. The
        window is what says so instead. Two things it says, and they answer
        different questions: whether it is still following the cursor says the
        gesture is still held, and whether it is back where it started says how
        the gesture ended, since Hyprland restores one it drops and leaves one
        the user dropped where they put it."""
        if not self.before:
            self.stop(cancelled=True)
            return
        if window and window["address"] != self.before["address"]:
            # Something else is focused, so the gesture is over however it
            # ended: a click elsewhere, a workspace switch, the window closing.
            self.stop(cancelled=True)
            return
        if not window:
            # A reply that never arrived says nothing either way.
            self.mark_settled(cursor_moved, dropped=False)
            return
        previous = self.window
        self.window = window
        if not self.moved(self.before, window):
            if self.left_origin:
                # It went somewhere and came back, which only Hyprland does.
                self.stop(cancelled=True)
                return
            # It has never moved at all. Hyprland leaves a tiled window alone
            # until the release swaps it, and a gesture it silently dropped
            # looks the same, so the only thing left is how long this lasts.
            self.mark_settled(cursor_moved, dropped=False)
            return
        self.left_origin = True
        if previous and shifted(previous, window):
            # Still keeping up with the cursor, so the gesture is still held.
            self.settled_at = None
            return
        # Away from where it started and no longer moving: the user let go, and
        # since Hyprland would have put it back had it dropped the gesture
        # itself, this is a drop to be tiled rather than a cancel.
        self.mark_settled(cursor_moved, dropped=True)

    def mark_settled(self, cursor_moved, dropped):
        now = time.monotonic()
        # A window that has stopped while the cursor carried on has been let go,
        # and that is clear within a frame or two. One that is merely sitting
        # still alongside a still cursor says nothing, so it has to last.
        # Resizes are the exception: a window at its minimum size stops while
        # the cursor keeps going and looks exactly like a released one, so they
        # wait it out instead.
        quick = dropped and cursor_moved and self.kind == "move"
        limit = STALE_FOLLOW_S if quick else STALE_DRAG_S
        if self.settled_at is None:
            self.settled_at = now
        elif now - self.settled_at > limit:
            self.stop(cancelled=not dropped)

    def event(self, name, data):
        """Hyprland announces the things that can only happen once a gesture is
        over long before the next poll would notice them."""
        if not self.dragging:
            return
        address = self.before["address"] if self.before else ""
        # Not `focusedmon`: Hyprland hands the active monitor over as the cursor
        # crosses, which a drag onto another screen does on its way there.
        if name in ("workspace", "workspacev2", "fullscreen"):
            self.stop(cancelled=True)
        elif name == "closewindow" and same_address(data, address):
            self.stop(cancelled=True)
        elif name == "activewindowv2" and data and not same_address(data, address):
            self.stop(cancelled=True)

    def moved(self, before, after):
        tol = self.tolerance
        return (abs(after["x"] - before["x"]) > tol or abs(after["y"] - before["y"]) > tol
                or abs(after["width"] - before["width"]) > tol
                or abs(after["height"] - before["height"]) > tol)

    def poll_idle(self):
        # Only the pre-drag geometry is of any use between gestures, and it is
        # one query: nothing here has to notice a drag, the binds do that.
        self.window = window_sample(self.ctl) or self.window

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
                    name, _, data = raw.decode(errors="replace").partition(">>")
                    if name == "configreloaded":
                        emit(read_gaps(ctl))
                    else:
                        monitor.event(name, data.split(",")[0].strip())

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
