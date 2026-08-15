#!/usr/bin/env python3
import fcntl
import glob
import json
import os
import stat
import sys
import tempfile
from contextlib import contextmanager


def sanitize_val(val, home_dir):
    if isinstance(val, dict):
        return {k: sanitize_val(v, home_dir) for k, v in val.items()}
    if isinstance(val, list):
        return [sanitize_val(x, home_dir) for x in val]
    if isinstance(val, str) and home_dir and home_dir in val:
        return val.replace(home_dir, "$HOME")
    return val


def normalize_path_field(data, section_name, field_name, home_dir, fallback=None):
    section = data.get(section_name)
    if not isinstance(section, dict) or field_name not in section:
        return

    value = section.get(field_name)
    if not isinstance(value, str) or not value:
        return

    path = value.strip()
    if path.startswith("file://"):
        path = path[7:]

    if path == "$HOME" or path.startswith("$HOME" + os.sep):
        section[field_name] = path
        return

    if home_dir and (path == home_dir or path.startswith(home_dir + os.sep)):
        section[field_name] = "$HOME" + path[len(home_dir):]
    elif os.path.isabs(path) and fallback:
        section[field_name] = fallback
    else:
        section[field_name] = path


def reset_monitor_bindings(data):
    background = data.get("background")
    if isinstance(background, dict) and isinstance(background.get("widgets"), dict):
        widgets = background["widgets"]
        widgets["showOnlyOnSingleMonitor"] = False
        widgets["targetMonitor"] = ""

    bar = data.get("bar")
    if isinstance(bar, dict):
        bar["onlyShowOnSingleMonitor"] = False
        bar["singleMonitorName"] = ""
        bar["screenList"] = []

        floating_notch = bar.get("floatingNotch")
        if isinstance(floating_notch, dict):
            floating_notch["onlyShowOnSingleMonitor"] = False
            floating_notch["singleMonitorName"] = ""

    interactions = data.get("interactions")
    if isinstance(interactions, dict) and isinstance(interactions.get("touchGestures"), dict):
        interactions["touchGestures"]["targetMonitor"] = "auto"

    notifications = data.get("notifications")
    if isinstance(notifications, dict) and isinstance(notifications.get("monitor"), dict):
        notifications["monitor"]["enable"] = False
        notifications["monitor"]["name"] = ""


def sanitize_data(data, home_dir):
    if "appearance" in data and isinstance(data["appearance"], dict):
        icons = data["appearance"].get("icons")
        if isinstance(icons, dict):
            icons["enableThemed"] = False
        data["appearance"]["iconTheme"] = ""

    data = sanitize_val(data, home_dir)
    normalize_path_field(data, "screenRecord", "savePath", home_dir, "$HOME/Videos")
    normalize_path_field(data, "screenSnip", "savePath", home_dir, "$HOME/Pictures/Screenshots")
    reset_monitor_bindings(data)
    return data


def expand_val(val, home_dir):
    if isinstance(val, dict):
        return {k: expand_val(v, home_dir) for k, v in val.items()}
    if isinstance(val, list):
        return [expand_val(x, home_dir) for x in val]
    if isinstance(val, str) and "$HOME" in val:
        return val.replace("$HOME", home_dir)
    return val


def deep_merge(base, overlay):
    """Merge mappings recursively; preset scalars/lists replace current values."""
    if not isinstance(base, dict) or not isinstance(overlay, dict):
        return overlay

    result = dict(base)
    for key, value in overlay.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def find_wallpaper_fallback(presets_dir, preset_name):
    pattern = os.path.join(presets_dir, f"{glob.escape(preset_name)}.*")
    for filepath in glob.glob(pattern):
        ext = os.path.splitext(filepath)[1].lower()
        if ext not in (".json", ".zip"):
            return filepath
    return None


def validate_preset_name(name):
    if not name or name in (".", ".."):
        raise ValueError("preset name is empty or reserved")
    if os.sep in name or (os.altsep and os.altsep in name):
        raise ValueError("preset name may not contain path separators")
    if any(ch in name for ch in ("\n", "\r", "\t", "\0")):
        raise ValueError("preset name may not contain control characters")


def load_json(path, fallback=None):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            value = json.load(handle)
        return value
    except FileNotFoundError:
        return fallback


def atomic_json_write(path, data):
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)

    old_mode = None
    try:
        old_mode = stat.S_IMODE(os.stat(path).st_mode)
    except FileNotFoundError:
        pass

    fd, tmp_path = tempfile.mkstemp(prefix=".preset-config-", suffix=".json", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=4)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        if old_mode is not None:
            os.chmod(tmp_path, old_mode)
        os.replace(tmp_path, path)
    finally:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass


def sanitize(input_path, output_path):
    data = load_json(input_path)
    if not isinstance(data, dict):
        raise ValueError("preset config must be a JSON object")

    home_dir = os.environ.get("HOME", "").rstrip("/")
    atomic_json_write(output_path, sanitize_data(data, home_dir))


def prepare_preset(input_path, presets_dir, preset_name):
    validate_preset_name(preset_name)
    data = load_json(input_path)
    if not isinstance(data, dict):
        raise ValueError("preset config must be a JSON object")

    home_dir = os.environ.get("HOME", "").rstrip("/")
    data = expand_val(data, home_dir)
    data.pop("_presetMeta", None)

    background = data.get("background")
    if isinstance(background, dict):
        wall_path = background.get("wallpaperPath", "")
        if not wall_path or not os.path.exists(wall_path):
            fallback = find_wallpaper_fallback(presets_dir, preset_name)
            if fallback:
                background["wallpaperPath"] = fallback
    return data


def expand(input_path, output_path, presets_dir, preset_name):
    atomic_json_write(output_path, prepare_preset(input_path, presets_dir, preset_name))


@contextmanager
def request_lock(token_file):
    lock_path = token_file + ".lock"
    os.makedirs(os.path.dirname(os.path.abspath(lock_path)), exist_ok=True)
    with open(lock_path, "a+", encoding="utf-8") as lock_handle:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX)
        yield
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_UN)


def request_is_current(token_file, request_id):
    try:
        with open(token_file, "r", encoding="utf-8") as handle:
            return handle.read().strip() == request_id
    except FileNotFoundError:
        return False


def apply_preset(input_path, output_path, presets_dir, preset_name, token_file, request_id):
    preset = prepare_preset(input_path, presets_dir, preset_name)
    current = load_json(output_path, fallback={})
    if not isinstance(current, dict):
        current = {}

    # Preserve options added by newer shell versions when applying an older
    # preset, matching the behavior of the upstream end4 preset path.
    merged = deep_merge(current, preset)

    # The token check and atomic replace share the same lock used by the shell
    # when registering newer requests. Therefore an older request can either
    # commit before a newer click is registered or be skipped entirely; it can
    # never overwrite a newer request after that newer request registered.
    with request_lock(token_file):
        if not request_is_current(token_file, request_id):
            print(json.dumps({"applied": False, "superseded": True}))
            return
        atomic_json_write(output_path, merged)

    appearance = merged.get("appearance", {}) if isinstance(merged.get("appearance"), dict) else {}
    background = merged.get("background", {}) if isinstance(merged.get("background"), dict) else {}
    theming = appearance.get("wallpaperTheming", {}) if isinstance(appearance.get("wallpaperTheming"), dict) else {}

    print(json.dumps({
        "applied": True,
        "superseded": False,
        "colorEngine": appearance.get("colorEngine", "vynx"),
        "wallpaperPath": background.get("wallpaperPath", ""),
        "themingEnabled": theming.get("enableAppsAndShell", True) is not False,
    }))


def list_presets(presets_dir):
    home_dir = os.environ.get("HOME", "").rstrip("/")
    pattern = os.path.join(presets_dir, "*.json")
    preset_files = sorted(glob.glob(pattern), key=lambda path: os.path.basename(path).lower())

    for json_path in preset_files:
        preset_name = os.path.splitext(os.path.basename(json_path))[0]
        try:
            data = load_json(json_path)
        except (OSError, ValueError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict):
            continue

        background = data.get("background", {})
        wall_path = background.get("wallpaperPath", "") if isinstance(background, dict) else ""
        if wall_path:
            wall_path = wall_path.replace("$HOME", home_dir)
        if not wall_path or not os.path.exists(wall_path):
            fallback = find_wallpaper_fallback(presets_dir, preset_name)
            if fallback:
                wall_path = fallback

        print(json.dumps({"name": preset_name, "wallpaper": wall_path}, separators=(",", ":")))


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    action = sys.argv[1]
    if action == "sanitize":
        if len(sys.argv) < 4:
            sys.exit(1)
        sanitize(sys.argv[2], sys.argv[3])
    elif action == "expand":
        if len(sys.argv) < 6:
            sys.exit(1)
        expand(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif action == "apply":
        if len(sys.argv) < 8:
            sys.exit(1)
        apply_preset(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
    elif action == "list":
        if len(sys.argv) < 3:
            sys.exit(1)
        list_presets(sys.argv[2])
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
