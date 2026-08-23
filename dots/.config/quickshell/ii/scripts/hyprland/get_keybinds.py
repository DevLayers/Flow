#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys

parser = argparse.ArgumentParser(description='Hyprland keybind reader')
parser.add_argument('--path', type=str, default=None,
                    help='path to keybind file (optional, uses hyprctl if not specified)')
args = parser.parse_args()


class KeyBinding(dict):
    def __init__(self, mods, key, dispatcher, params, comment):
        self["mods"] = mods
        self["key"] = key
        self["dispatcher"] = dispatcher
        self["params"] = params
        self["comment"] = comment


class Unbinding(dict):
    def __init__(self, mods, key, comment):
        self["mods"] = mods
        self["key"] = key
        self["comment"] = comment


class Section(dict):
    def __init__(self, children, keybinds, unbinds, name):
        self["children"] = children
        self["keybinds"] = keybinds
        self["unbinds"] = unbinds
        self["name"] = name


MODMASKS = {
    1: "SHIFT",
    4: "ALT",
    8: "CTRL",
    64: "SUPER",
}


def decode_modmask(mask):
    parts = []
    for val, name in sorted(MODMASKS.items()):
        if mask & val:
            parts.append(name)
    return parts


def autogenerate_comment(dispatcher, params=""):
    match dispatcher:
        case "resizewindow":
            return "Resize window"
        case "movewindow":
            if params == "":
                return "Move window"
            return "Window: move in {} direction".format({
                "l": "left", "r": "right", "u": "up", "d": "down",
            }.get(params, "null"))
        case "pin":
            return "Window: pin (show on all workspaces)"
        case "splitratio":
            return "Window split ratio {}".format(params)
        case "togglefloating":
            return "Float/unfloat window"
        case "resizeactive":
            return "Resize window by {}".format(params)
        case "killactive":
            return "Close window"
        case "fullscreen":
            return "Toggle {}".format({"0": "fullscreen", "1": "maximization", "2": "fullscreen on Hyprland's side"}.get(params, "null"))
        case "fakefullscreen":
            return "Toggle fake fullscreen"
        case "workspace":
            if params == "+1":
                return "Workspace: focus right"
            elif params == "-1":
                return "Workspace: focus left"
            return "Focus workspace {}".format(params)
        case "movefocus":
            return "Window: move focus {}".format({"l": "left", "r": "right", "u": "up", "d": "down"}.get(params, "null"))
        case "swapwindow":
            return "Window: swap in {} direction".format({"l": "left", "r": "right", "u": "up", "d": "down"}.get(params, "null"))
        case "movetoworkspace":
            if params == "+1":
                return "Window: move to right workspace (non-silent)"
            elif params == "-1":
                return "Window: move to left workspace (non-silent)"
            return "Window: move to workspace {} (non-silent)".format(params)
        case "movetoworkspacesilent":
            if params == "+1":
                return "Window: move to right workspace"
            elif params == "-1":
                return "Window: move to left workspace"
            return "Window: move to workspace {}".format(params)
        case "togglespecialworkspace":
            return "Workspace: toggle special"
        case "exec":
            return "Execute: {}".format(params)
        case _:
            return ""


# ─── Lua parser ──────────────────────────────────────────────────────────────

LUA_BIND_RE = re.compile(r'hl\.bind\s*\(([^)]*)\)\s*', re.DOTALL)
LUA_FIRST_ARG_RE = re.compile(r'"([^"]+)"')
LUA_DESC_RE = re.compile(r'description\s*=\s*"([^"]*)"')
LUA_SECTION_RE = re.compile(r'^--##!\s+(.+)$')
LUA_COMMENT_BIND_PATTERN = re.compile(r'^--?#/#\s+(bind|unbind)\w*\s*=')
LUA_DISPATCH_RE = re.compile(
    r'hl\.dsp\.(?P<dispatcher>global|exec_cmd)\s*\(\s*"(?P<params>(?:\\.|[^"\\])*)"\s*\)',
    re.DOTALL,
)


def parse_lua_binds(path):
    with open(os.path.expanduser(os.path.expandvars(path)), 'r') as f:
        content = f.read()

    root = Section([], [], [], "")
    stack = [(root, 0)]
    current = root

    lines = content.split('\n')
    i = 0
    while i < len(lines):
        raw = lines[i]

        # Section header
        m = re.match(LUA_SECTION_RE, raw)
        if m:
            scope = 2
            name = m.group(1).strip()
            while stack and stack[-1][1] >= scope:
                stack.pop()
            new_section = Section([], [], [], name)
            stack[-1][0]["children"].append(new_section)
            stack.append((new_section, scope))
            current = new_section
            i += 1
            continue

        # hl.bind call - may span multiple lines
        stripped = raw.strip()
        if stripped.startswith('hl.bind('):
            bind_src = stripped
            # collect continuation lines until matching closing paren
            depth = stripped.count('(') - stripped.count(')')
            i += 1
            while depth > 0 and i < len(lines):
                line = lines[i]
                bind_src += '\n' + line
                depth += line.count('(') - line.count(')')
                i += 1
            process_lua_bind(bind_src, current)
            continue

        # hl.unbind
        if stripped.startswith('hl.unbind('):
            bind_src = stripped
            depth = stripped.count('(') - stripped.count(')')
            i += 1
            while depth > 0 and i < len(lines):
                line = lines[i]
                bind_src += '\n' + line
                depth += line.count('(') - line.count(')')
                i += 1
            process_lua_bind(bind_src, current, is_unbind=True)
            continue

        # Cheatsheet-only documentation binds (not registered with Hyprland)
        # e.g. `--#/# bind = SUPER+SHIFT, ↑/↓/←/→,, # Move workspace to monitor`
        if re.match(LUA_COMMENT_BIND_PATTERN, stripped):
            # Strip leading `--` so conf-style parsing sees `#/# bind = ...`
            lines[i] = stripped[2:].lstrip() if stripped.startswith("--") else stripped
            keybind = get_keybind_at_line(i, lines)
            if isinstance(keybind, KeyBinding):
                current["keybinds"].append(keybind)
            elif isinstance(keybind, Unbinding):
                current["unbinds"].append(keybind)
            i += 1
            continue

        i += 1

    # Wrap orphan root keybinds/unbinds into an implicit section so QML
    # (which walks .children) can discover them.
    if (root.get("keybinds") and len(root["keybinds"]) > 0) or \
       (root.get("unbinds") and len(root["unbinds"]) > 0):
        implicit = Section(
            [],
            list(root.get("keybinds") or []),
            list(root.get("unbinds") or []),
            "Keybinds",
        )
        root["children"].insert(0, implicit)
        root["keybinds"] = []
        root["unbinds"] = []

    # Nest each section's direct keybinds into a synthetic child sub-section
    # so the QML parseKeymaps function sees child.children with keybind data.
    # Unbinds stay on the section itself — parseUnbinds walks all nodes.
    for section in root["children"]:
        if section.get("keybinds") and len(section["keybinds"]) > 0:
            sub = Section([], list(section["keybinds"]), [], section.get("name", ""))
            section["children"].append(sub)
            section["keybinds"] = []

    return root


def process_lua_bind(bind_src, current, is_unbind=False):
    # Extract the first string argument: mods + key
    m = LUA_FIRST_ARG_RE.search(bind_src)
    if not m:
        return
    combo = m.group(1)
    parts = [p.strip() for p in combo.split('+')]
    mods = parts[:-1] if len(parts) > 1 else []
    key = parts[-1]

    # Extract description from options table
    desc_m = LUA_DESC_RE.search(bind_src)
    comment = desc_m.group(1).strip() if desc_m else ''

    # Check for [hidden] or [ignore] markers
    if '[hidden]' in comment or '[ignore]' in comment:
        return

    if is_unbind:
        # Unbinds don't need descriptions — they only filter the cheatsheet
        current["unbinds"].append(Unbinding(mods, key, comment))
        return

    # Skip binds without descriptions (they're internal).
    if not comment:
        return

    # The Lua frontend registers its binds as internal `__lua` callbacks, so
    # `hyprctl binds` cannot expose the command that should run. Preserve the
    # literal dispatchers the frontend declares instead. The Search can then
    # invoke `global quickshell:…` or `exec …` through Hyprland.dispatch when
    # the selected keybind receives Enter.
    dispatch_match = LUA_DISPATCH_RE.search(bind_src)
    dispatcher = ''
    params = ''
    if dispatch_match:
        dispatcher = 'exec' if dispatch_match.group('dispatcher') == 'exec_cmd' else 'global'
        params = bytes(dispatch_match.group('params'), 'utf-8').decode('unicode_escape')

    current["keybinds"].append(KeyBinding(mods, key, dispatcher, params, comment))


# ─── Conf parser (original) ──────────────────────────────────────────────────

TITLE_REGEX = r"#+!"
COMMENT_BIND_PATTERN = r"^\s*#/#\s+(bind|unbind)\s*="
HIDE_COMMENT = "[hidden]"
MOD_SEPARATORS = ['+', ' ']


def read_content(path):
    expanded = os.path.expanduser(os.path.expandvars(path))
    if not os.access(expanded, os.R_OK):
        return "error"
    with open(expanded, "r") as file:
        return file.read()


def get_keybind_at_line(line_number, content_lines, line_start=0):
    line = content_lines[line_number]
    command, keys = line.split("=", 1)

    keys, *comment = keys.split("#", 1)

    if 'unbind' in command:
        comment = list(map(str.strip, comment))
        if comment:
            comment = comment[0]
            if comment.startswith("[ignore]"):
                return None
        mods, key, *_ = list(map(str.strip, keys.split(",", 3)))
        if mods:
            modstring = mods + MOD_SEPARATORS[0]
            mods = []
            p = 0
            for index, char in enumerate(modstring):
                if char in MOD_SEPARATORS:
                    if index - p > 1:
                        mods.append(modstring[p:index])
                    p = index + 1
        else:
            mods = []
        return Unbinding(mods, key, comment)

    mods, key, dispatcher, *params = list(map(str.strip, keys.split(",", 4)))
    params = "".join(map(str.strip, params))
    comment = list(map(str.strip, comment))

    if comment:
        comment = comment[0]
        if comment.startswith("[hidden]"):
            return None
    else:
        comment = autogenerate_comment(dispatcher, params)

    if mods:
        modstring = mods + MOD_SEPARATORS[0]
        mods = []
        p = 0
        for index, char in enumerate(modstring):
            if char in MOD_SEPARATORS:
                if index - p > 1:
                    mods.append(modstring[p:index])
                p = index + 1
    else:
        mods = []

    return KeyBinding(mods, key, dispatcher, params, comment)


def get_binds_recursive(current_content, scope, content_lines, reading_line):
    while reading_line < len(content_lines):
        line = content_lines[reading_line]
        heading_search_result = re.search(TITLE_REGEX, line)
        if heading_search_result is not None and heading_search_result.start() == 0:
            heading_scope = line.find('!')
            if heading_scope <= scope:
                reading_line -= 1
                return current_content, reading_line
            section_name = line[(heading_scope + 1):].strip()
            reading_line += 1
            child, reading_line = get_binds_recursive(Section([], [], [], section_name), heading_scope, content_lines, reading_line)
            current_content["children"].append(child)

        elif re.match(COMMENT_BIND_PATTERN, line):
            keybind = get_keybind_at_line(reading_line, content_lines, line_start=len("#/# "))
            if isinstance(keybind, KeyBinding):
                current_content["keybinds"].append(keybind)
            elif isinstance(keybind, Unbinding):
                current_content["unbinds"].append(keybind)
            reading_line += 1

        elif line == "" or not (line.lstrip().startswith("bind") or line.lstrip().startswith("unbind")):
            reading_line += 1

        else:
            keybind = get_keybind_at_line(reading_line, content_lines)
            if isinstance(keybind, KeyBinding):
                current_content["keybinds"].append(keybind)
            elif isinstance(keybind, Unbinding):
                current_content["unbinds"].append(keybind)
            reading_line += 1

    return current_content, reading_line


def parse_conf(path):
    content = read_content(path)
    if content == "error":
        return "error"
    content_lines = content.splitlines()
    result, _ = get_binds_recursive(Section([], [], [], ""), 0, content_lines, 0)
    return result


# ─── hyprctl fallback ───────────────────────────────────────────────────────

def parse_hyprctl():
    try:
        result = subprocess.run(['hyprctl', 'binds', '-j'],
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            return "error"
        binds = json.loads(result.stdout)
    except Exception:
        return "error"

    root = Section([], [], [], "")
    section_map = {}

    for b in binds:
        desc = b.get('description', '').strip()
        if not desc:
            continue
        if desc.startswith('[hidden]'):
            continue

        mods = decode_modmask(b.get('modmask', 0))
        key = b.get('key', '')

        section_name = "Misc"
        if ':' in desc:
            prefix = desc.split(':')[0]
            if prefix:
                section_name = prefix

        if section_name not in section_map:
            sec = Section([], [], [], section_name)
            root["children"].append(sec)
            section_map[section_name] = sec

        section_map[section_name]["keybinds"].append(
            KeyBinding(mods, key, b.get('dispatcher', ''), b.get('arg', ''), desc)
        )

    return root


# ─── Main ────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    path = args.path

    result = None
    if path:
        expanded = os.path.expanduser(os.path.expandvars(path))
        if not os.access(expanded, os.R_OK):
            # File doesn't exist or isn't readable - return empty
            result = Section([], [], [], "")
        else:
            try:
                if path.lower().endswith('.lua'):
                    result = parse_lua_binds(path)
                else:
                    result = parse_conf(path)
            except Exception:
                result = "error"

    if result is None or result == "error":
        result = parse_hyprctl()

    if result == "error":
        result = Section([], [], [], "")

    print(json.dumps(result))
