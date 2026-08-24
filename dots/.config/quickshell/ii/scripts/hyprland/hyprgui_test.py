#!/usr/bin/env python3
"""Round-trip tests for hyprgui.py. Run it directly: ./hyprgui_test.py"""
import json, os, shutil, subprocess, sys, tempfile

G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hyprgui.py")
FAIL = []

ENV = dict(os.environ)

def run(args, stdin=None):
    p = subprocess.run([G] + args, input=stdin, capture_output=True, text=True, env=ENV)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

def check(name, cond, detail=""):
    print(("PASS  " if cond else "FAIL  ") + name + (("  -- " + str(detail)) if not cond and detail else ""))
    if not cond: FAIL.append(name)

work = tempfile.mkdtemp(prefix="hyprgui-test-")
custom = os.path.join(work, "custom"); os.makedirs(custom)
ENV["XDG_STATE_HOME"] = os.path.join(work, "state")   # keep test backups out of ~/.local/state

HAND = '''-- hand written header
local function wanted_transform()
    return 0
end

hl.config({ input = { kb_layout = "fr" } })
hl.monitor({ output = "eDP-1", mode = "preferred" })
'''
target = os.path.join(custom, "general.lua")
open(target, "w").write(HAND)

NASTY = 'a"b\\c$|x'   # one quote, one backslash, a dollar and a pipe

DOC = {"version": 1, "entries": [
    {"kind": "config", "id": "input:kb_layout", "key": "input:kb_layout", "value": "us"},
    {"kind": "config", "id": "input:repeat_rate", "key": "input:repeat_rate", "value": 35},
    {"kind": "config", "id": "input:touchpad:tap-to-click", "key": "input:touchpad:tap-to-click", "value": True},
    {"kind": "config", "id": "cursor:inactive_timeout", "key": "cursor:inactive_timeout", "value": 3.5},
    {"kind": "device", "id": "mouse-1", "spec": {"name": "znt0001:00-14e5:e760-mouse", "sensitivity": -0.2}},
    {"kind": "env", "id": "XCURSOR_SIZE", "name": "XCURSOR_SIZE", "value": "24"},
    {"kind": "windowrule", "id": "w1", "spec": {"match": {"class": "^(kitty)$", "title": NASTY}, "float": True, "size": ["60%", "50%"]}},
    {"kind": "layerrule", "id": "l1", "spec": {"match": {"namespace": "^(waybar)$"}, "blur": True}},
    {"kind": "workspacerule", "id": "s1", "spec": {"workspace": "2", "persistent": True, "layout_opts": {"orientation": "left"}}},
    {"kind": "unbind", "id": "SUPER + T", "key": "SUPER + T"},
    {"kind": "bind", "id": "b1", "key": "SUPER + T", "dispatcher": {"__raw": "hl.dsp.exec_cmd(\"kitty -1\")"},
     "opts": {"description": "Terminal", "repeating": False}},
]}

rc, out, err = run(["write", "--file", target, "--json", "-", "--custom-dir", custom], json.dumps(DOC))
r = json.loads(out) if out.startswith("{") else {}
check("write succeeds", rc == 0 and r.get("ok") and r.get("changed"), out + err)

body = open(target).read()
check("hand-written header preserved", body.startswith(HAND.rstrip("\n").split("\n")[0]), body[:80])
check("wanted_transform preserved", "local function wanted_transform()" in body)
check("hl.monitor untouched", "hl.monitor({ output = \"eDP-1\", mode = \"preferred\" })" in body)
check("region at end of file", body.rstrip().endswith("-- <<< quickshell:managed:end"))
check("pre-fence kb_layout survives", body.count('hl.config({ input = { kb_layout = "fr" } })') == 1)

rc2, out2, _ = run(["write", "--file", target, "--json", "-", "--custom-dir", custom], json.dumps(DOC))
r2 = json.loads(out2)
check("second identical write is a no-op", r2.get("ok") and r2.get("changed") is False, out2)

rc3, out3, _ = run(["read", "--file", target])
back = json.loads(out3)
check("read finds the region", back["hasRegion"] and back["regionVersion"] == 1)
check("all entries round-trip", len(back["entries"]) == len(DOC["entries"]),
      [e.get("kind") for e in back["entries"]])
by_id = {e.get("id"): e for e in back["entries"]}
check("string value round-trips", by_id.get("input:kb_layout", {}).get("value") == "us")
check("int value round-trips", by_id.get("input:repeat_rate", {}).get("value") == 35)
check("bool value round-trips", by_id.get("input:touchpad:tap-to-click", {}).get("value") is True)
check("float value round-trips", by_id.get("cursor:inactive_timeout", {}).get("value") == 3.5)
check("dashed key quoted+read", 'input = { ["tap-to-click"]' in body or '["tap-to-click"]' in body, body)
check("device spec round-trips", by_id.get("mouse-1", {}).get("spec", {}).get("sensitivity") == -0.2)
check("env round-trips", by_id.get("XCURSOR_SIZE", {}).get("value") == "24")
w1 = by_id.get("w1", {}).get("spec", {})
check("regex with $ | \\ and quote round-trips", w1.get("match", {}).get("title") == NASTY, w1)
check("array value round-trips", w1.get("size") == ["60%", "50%"])
check("nested rule table round-trips",
      by_id.get("s1", {}).get("spec", {}).get("layout_opts") == {"orientation": "left"})
check("unbind round-trips", by_id.get("SUPER + T", {}).get("kind") == "unbind")
b1 = by_id.get("b1", {})
check("bind dispatcher kept raw", b1.get("dispatcher") == {"__raw": 'hl.dsp.exec_cmd("kitty -1")'}, b1)
check("bind opts round-trip", b1.get("opts") == {"description": "Terminal", "repeating": False}, b1)
check("unmanaged pre-fence key reported",
      any(e["kind"] == "config" and e["key"] == "input:kb_layout" and e["value"] == "fr"
          for e in back["unmanaged"]), back["unmanaged"])

# Unknown lines inside the fence survive.
lines = open(target).read().split("\n")
idx = next(i for i, l in enumerate(lines) if l.startswith("hl.env"))
lines.insert(idx, 'hl.config({ future = { thing = 1 } })  --@z future:thing')
open(target, "w").write("\n".join(lines))
rc4, out4, _ = run(["read", "--file", target])
back4 = json.loads(out4)
raws = [e for e in back4["entries"] if e["kind"] == "raw"]
check("unknown tagged line kept as raw", len(raws) == 1 and "future" in raws[0]["text"], raws)

# Rewriting with the raw entry preserved keeps it verbatim.
doc2 = {"version": 1, "entries": back4["entries"]}
run(["write", "--file", target, "--json", "-", "--custom-dir", custom], json.dumps(doc2))
check("raw line survives a rewrite", "--@z future:thing" in open(target).read())

# Dry run does not touch the file.
before = open(target).read()
doc3 = {"version": 1, "entries": [DOC["entries"][0]]}
rc5, out5, _ = run(["write", "--file", target, "--json", "-", "--custom-dir", custom, "--dry-run"], json.dumps(doc3))
r5 = json.loads(out5)
check("dry-run returns a diff", r5.get("diff", "").startswith("---"), out5[:200])
check("dry-run leaves the file alone", open(target).read() == before)

# Strip removes the fence and nothing else.
rc6, out6, _ = run(["strip", "--file", target, "--custom-dir", custom])
after = open(target).read()
check("strip removes the region", "quickshell:managed" not in after, after[-200:])
check("strip keeps hand-written Lua", "local function wanted_transform()" in after and "hl.monitor" in after)

# Path guard.
outside = os.path.join(work, "main.lua"); open(outside, "w").write("-- upstream\n")
rc7, out7, err7 = run(["write", "--file", outside, "--json", "-", "--custom-dir", custom], json.dumps(DOC))
check("refuses to write outside custom/", rc7 != 0 and open(outside).read() == "-- upstream\n", err7)
rc8, out8, err8 = run(["write", "--file", os.path.join(custom, "..", "hyprland", "x.lua"),
                       "--json", "-", "--custom-dir", custom], json.dumps(DOC))
check("refuses traversal out of custom/", rc8 != 0, err8)

# Missing file gets created.
fresh = os.path.join(custom, "env.lua")
rc9, out9, _ = run(["write", "--file", fresh, "--json", "-", "--custom-dir", custom],
                   json.dumps({"version": 1, "entries": [DOC["entries"][5]]}))
r9 = json.loads(out9)
check("creates a missing file", r9.get("created") is True and os.path.exists(fresh), out9)
check("no backup for a created file", r9.get("backup") is None)
check("backups land under XDG_STATE_HOME",
      os.path.isdir(os.path.join(work, "state", "quickshell", "hyprland-backups")))

# Empty entry list strips the region.
rc10, out10, _ = run(["write", "--file", fresh, "--json", "-", "--custom-dir", custom],
                     json.dumps({"version": 1, "entries": []}))
check("empty document removes the region", "quickshell:managed" not in open(fresh).read())

shutil.rmtree(work)
print()
print("%d failed" % len(FAIL) if FAIL else "all passed")
sys.exit(1 if FAIL else 0)
