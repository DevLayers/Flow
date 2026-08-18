#!/usr/bin/env python3
import json
import os
import sys
import glob

def sanitize_val(val, home_dir):
    if isinstance(val, dict):
        return {k: sanitize_val(v, home_dir) for k, v in val.items()}
    elif isinstance(val, list):
        return [sanitize_val(x, home_dir) for x in val]
    elif isinstance(val, str):
        if home_dir and home_dir in val:
            return val.replace(home_dir, '$HOME')
        return val
    return val

def normalize_path_field(data, section_name, field_name, home_dir, fallback=None):
    section = data.get(section_name)
    if not isinstance(section, dict) or field_name not in section:
        return

    value = section.get(field_name)
    if not isinstance(value, str) or not value:
        return

    path = value.strip()
    if path.startswith('file://'):
        path = path[7:]

    if path == '$HOME' or path.startswith('$HOME' + os.sep):
        section[field_name] = path
        return

    if home_dir and (path == home_dir or path.startswith(home_dir + os.sep)):
        section[field_name] = '$HOME' + path[len(home_dir):]
    elif os.path.isabs(path) and fallback:
        section[field_name] = fallback
    else:
        section[field_name] = path

def reset_monitor_bindings(data):
    background = data.get('background')
    if isinstance(background, dict) and isinstance(background.get('widgets'), dict):
        widgets = background['widgets']
        widgets['showOnlyOnSingleMonitor'] = False
        widgets['targetMonitor'] = ''

    bar = data.get('bar')
    if isinstance(bar, dict):
        bar['onlyShowOnSingleMonitor'] = False
        bar['singleMonitorName'] = ''
        bar['screenList'] = []

        floating_notch = bar.get('floatingNotch')
        if isinstance(floating_notch, dict):
            floating_notch['onlyShowOnSingleMonitor'] = False
            floating_notch['singleMonitorName'] = ''

    interactions = data.get('interactions')
    if isinstance(interactions, dict) and isinstance(interactions.get('touchGestures'), dict):
        interactions['touchGestures']['targetMonitor'] = 'auto'

    notifications = data.get('notifications')
    if isinstance(notifications, dict) and isinstance(notifications.get('monitor'), dict):
        notifications['monitor']['enable'] = False
        notifications['monitor']['name'] = ''

def sanitize_data(data, home_dir):
    if 'appearance' in data and isinstance(data['appearance'], dict):
        icons = data['appearance'].get('icons')
        if isinstance(icons, dict):
            icons['enableThemed'] = False
        data['appearance']['iconTheme'] = ''

    data = sanitize_val(data, home_dir)

    # Keep user paths portable when a preset is imported by another account.
    normalize_path_field(data, 'screenRecord', 'savePath', home_dir, '$HOME/Videos')
    normalize_path_field(data, 'screenSnip', 'savePath', home_dir, '$HOME/Pictures/Screenshots')

    # Monitor connector names are local to the source machine.
    reset_monitor_bindings(data)
    return data

def sanitize(input_path, output_path):
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    home_dir = os.environ.get('HOME', '')
    if home_dir.endswith('/'):
        home_dir = home_dir[:-1]

    data = sanitize_data(data, home_dir)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4)

def expand_val(val, home_dir):
    if isinstance(val, dict):
        return {k: expand_val(v, home_dir) for k, v in val.items()}
    elif isinstance(val, list):
        return [expand_val(x, home_dir) for x in val]
    elif isinstance(val, str):
        if '$HOME' in val:
            return val.replace('$HOME', home_dir)
        return val
    return val

def expand(input_path, output_path, presets_dir, preset_name):
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    home_dir = os.environ.get('HOME', '')
    if home_dir.endswith('/'):
        home_dir = home_dir[:-1]
        
    data = expand_val(data, home_dir)
    
    # Check if background.wallpaperPath exists
    bg = data.get('background', {})
    if isinstance(bg, dict):
        wall_path = bg.get('wallpaperPath', '')
        if not wall_path or not os.path.exists(wall_path):
            # Check for fallback file in presets_dir
            fallback = find_wallpaper_fallback(presets_dir, preset_name)
            if fallback:
                bg['wallpaperPath'] = fallback
                data['background'] = bg
                
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4)

def find_wallpaper_fallback(presets_dir, preset_name):
    pattern = os.path.join(presets_dir, f"{preset_name}.*")
    for filepath in glob.glob(pattern):
        ext = os.path.splitext(filepath)[1].lower()
        if ext not in ('.json', '.zip'):
            return filepath
    return None

def list_presets(presets_dir):
    home_dir = os.environ.get('HOME', '')
    if home_dir.endswith('/'):
        home_dir = home_dir[:-1]
        
    pattern = os.path.join(presets_dir, "*.json")
    # Sort presets by name case-insensitively
    preset_files = sorted(glob.glob(pattern), key=lambda x: os.path.basename(x).lower())
    for json_path in preset_files:
        filename = os.path.basename(json_path)
        preset_name = os.path.splitext(filename)[0]
        
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception:
            continue
            
        bg = data.get('background', {})
        wall_path = ''
        if isinstance(bg, dict):
            wall_path = bg.get('wallpaperPath', '')
            if wall_path:
                wall_path = wall_path.replace('$HOME', home_dir)
                
        if not wall_path or not os.path.exists(wall_path):
            fallback = find_wallpaper_fallback(presets_dir, preset_name)
            if fallback:
                wall_path = fallback
                
        print(json.dumps({"name": preset_name, "wallpaper": wall_path}))

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
        
    action = sys.argv[1]
    if action == 'sanitize':
        if len(sys.argv) < 4:
            sys.exit(1)
        sanitize(sys.argv[2], sys.argv[3])
    elif action == 'expand':
        if len(sys.argv) < 6:
            sys.exit(1)
        expand(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif action == 'list':
        if len(sys.argv) < 3:
            sys.exit(1)
        list_presets(sys.argv[2])
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
