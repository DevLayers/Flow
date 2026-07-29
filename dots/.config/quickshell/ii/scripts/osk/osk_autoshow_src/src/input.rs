//! Watches physical input devices so the shell can tell *how* a text field was
//! reached: by finger, by pen, or by mouse/keyboard.
//!
//! The Wayland input-method protocol reports that a text field was focused but not
//! which device caused it, so the QML side correlates an `activate` line with the
//! most recent `touch`/`pen` line to decide whether to raise the keyboard.

use std::path::PathBuf;
use std::thread;
use std::time::{Duration, Instant};

use evdev::{AbsInfo, AbsoluteAxisCode, Device, EventSummary, KeyCode, PropType};

use crate::emit::emit;

#[derive(Clone, Copy, PartialEq)]
enum Role {
    Touch,
    Pen,
    Keyboard,
}

impl Role {
    fn label(self) -> &'static str {
        match self {
            Role::Touch => "touch",
            Role::Pen => "pen",
            Role::Keyboard => "key",
        }
    }
}

/// Devices we inject through ourselves. Reacting to these would make the OSK
/// close itself the moment the user pressed one of its own keys.
fn is_virtual(name: &str) -> bool {
    let name = name.to_ascii_lowercase();
    name.contains("ydotool") || name.contains("virtual") || name.contains("uinput")
}

fn classify(dev: &Device) -> Option<Role> {
    let keys = dev.supported_keys()?;

    if keys.contains(KeyCode::BTN_TOOL_PEN) {
        return Some(Role::Pen);
    }
    // INPUT_PROP_DIRECT distinguishes a touchscreen from a touchpad.
    if keys.contains(KeyCode::BTN_TOUCH) && dev.properties().contains(PropType::DIRECT) {
        return Some(Role::Touch);
    }
    if keys.contains(KeyCode::KEY_A) && keys.contains(KeyCode::KEY_Z) && keys.contains(KeyCode::KEY_SPACE) {
        return Some(Role::Keyboard);
    }
    None
}

/// Spawns one watcher thread per interesting device. Devices that cannot be opened
/// (permission, hotplug race) are skipped silently — the daemon stays useful with
/// whatever it can read.
pub fn spawn_watchers() {
    for (path, dev) in evdev::enumerate() {
        let name = dev.name().unwrap_or_default().to_string();
        if is_virtual(&name) {
            continue;
        }

        let Some(role) = classify(&dev) else {
            continue;
        };
        drop(dev);

        thread::spawn(move || loop {
            if watch(&path, role).is_err() {
                // Device disappeared (suspend, unplug). Back off and retry so a
                // resumed touchscreen starts reporting again without a restart.
                thread::sleep(Duration::from_secs(2));
            }
        });
    }
}

fn axis_range(dev: &Device, axis: AbsoluteAxisCode) -> Option<AbsInfo> {
    dev.get_absinfo().ok()?.find(|(code, _)| *code == axis).map(|(_, info)| info)
}

fn normalize(value: i32, info: Option<AbsInfo>) -> f32 {
    let Some(info) = info else {
        return -1.0;
    };
    let span = (info.maximum() - info.minimum()) as f32;
    if span <= 0.0 {
        return -1.0;
    }
    ((value - info.minimum()) as f32 / span).clamp(0.0, 1.0)
}

fn watch(path: &PathBuf, role: Role) -> std::io::Result<()> {
    let mut dev = Device::open(path)?;

    // Multitouch panels report contacts on ABS_MT_*; pens and single-touch panels
    // use plain ABS_X/ABS_Y.
    let (x_axis, y_axis) = if role == Role::Touch && axis_range(&dev, AbsoluteAxisCode::ABS_MT_POSITION_X).is_some() {
        (AbsoluteAxisCode::ABS_MT_POSITION_X, AbsoluteAxisCode::ABS_MT_POSITION_Y)
    } else {
        (AbsoluteAxisCode::ABS_X, AbsoluteAxisCode::ABS_Y)
    };
    let x_info = axis_range(&dev, x_axis);
    let y_info = axis_range(&dev, y_axis);

    let mut x = 0.0f32;
    let mut y = 0.0f32;
    let mut last_key = Instant::now() - Duration::from_secs(1);

    loop {
        for event in dev.fetch_events()? {
            match event.destructure() {
                EventSummary::AbsoluteAxis(_, code, value) if code == x_axis => x = normalize(value, x_info),
                EventSummary::AbsoluteAxis(_, code, value) if code == y_axis => y = normalize(value, y_info),

                EventSummary::Key(_, code, 1) => {
                    if role == Role::Keyboard {
                        // A held key repeats; one line per burst is enough to hide the OSK.
                        if last_key.elapsed() >= Duration::from_millis(200) {
                            last_key = Instant::now();
                            emit(role.label());
                        }
                    } else if code == KeyCode::BTN_TOUCH {
                        // Contact down — the position from this same SYN batch is current.
                        emit(&format!("{} {:.4} {:.4}", role.label(), x, y));
                    }
                }
                _ => {}
            }
        }
    }
}
