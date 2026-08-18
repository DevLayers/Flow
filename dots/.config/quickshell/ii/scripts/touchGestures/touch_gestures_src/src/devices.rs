use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use evdev::{AbsInfo, AbsoluteAxisCode, Device, EventSummary, KeyCode, PropType};

use crate::protocol::{emit_event, OutEvent};

pub fn is_touchscreen(dev: &Device) -> bool {
    let name_lower = dev.name().unwrap_or("").to_ascii_lowercase();

    // Explicitly reject touchpads
    if name_lower.contains("touchpad") {
        return false;
    }

    // Pointer-only devices without DIRECT property (like laptop touchpads or mice)
    if dev.properties().contains(PropType::POINTER)
        && !dev.properties().contains(PropType::DIRECT)
        && !name_lower.contains("mouse passthrough (absolute)")
        && !name_lower.contains("sunshine")
        && !name_lower.contains("moonlight")
    {
        return false;
    }

    if let Some(keys) = dev.supported_keys() {
        // Direct physical touchscreen or tablet (e.g. BTN_TOUCH or BTN_TOOL_PEN with DIRECT prop)
        if (keys.contains(KeyCode::BTN_TOUCH) || keys.contains(KeyCode::BTN_TOOL_PEN))
            && dev.properties().contains(PropType::DIRECT)
        {
            return true;
        }

        // Multi-touch direct screen (non-pointer)
        if let Some(axes) = dev.supported_absolute_axes() {
            if axes.contains(AbsoluteAxisCode::ABS_MT_POSITION_X)
                && dev.properties().contains(PropType::DIRECT)
            {
                return true;
            }
        }

        // Sunshine / Moonlight / Absolute remote touchscreen emulation
        if name_lower.contains("mouse passthrough (absolute)")
            || name_lower.contains("sunshine")
            || name_lower.contains("moonlight")
        {
            if let Some(axes) = dev.supported_absolute_axes() {
                if axes.contains(AbsoluteAxisCode::ABS_X)
                    && axes.contains(AbsoluteAxisCode::ABS_Y)
                    && (keys.contains(KeyCode::BTN_LEFT) || keys.contains(KeyCode::BTN_TOUCH))
                {
                    return true;
                }
            }
        }
    }

    false
}

/// Stylus/digitizer devices also report BTN_TOUCH + INPUT_PROP_DIRECT, so they pass
/// `is_touchscreen`. They are reported separately so the shell can decide whether pen
/// input should drive gestures (a pen is also a pointer, so it drags windows too).
pub fn is_stylus(dev: &Device) -> bool {
    let name_lower = dev.name().unwrap_or("").to_ascii_lowercase();
    if name_lower.contains("tablet") || name_lower.contains("stylus") || name_lower.contains("pen") {
        return true;
    }
    dev.supported_keys().is_some_and(|keys| {
        keys.contains(KeyCode::BTN_TOOL_PEN)
            || keys.contains(KeyCode::BTN_STYLUS)
            || keys.contains(KeyCode::BTN_STYLUS2)
            || keys.contains(KeyCode::BTN_TOOL_RUBBER)
    })
}

pub fn is_desktop_mapped(dev: &Device) -> bool {
    let name_lower = dev.name().unwrap_or("").to_ascii_lowercase();
    if name_lower.contains("opentabletdriver")
        || name_lower.contains("sunshine")
        || name_lower.contains("moonlight")
        || name_lower.contains("mouse passthrough (absolute)")
    {
        return true;
    }
    if let Ok(mut iter) = dev.get_absinfo() {
        if let Some((_, info)) = iter.find(|(c, _)| *c == AbsoluteAxisCode::ABS_X) {
            if info.maximum() > 100000 {
                return true;
            }
        }
    }
    false
}

pub fn is_virtual(name: &str) -> bool {
    let name = name.to_ascii_lowercase();
    name.contains("ydotool")
}

pub fn stable_device_id(dev: &Device) -> String {
    let id = dev.input_id();
    let name_sanitized = dev
        .name()
        .unwrap_or("touchscreen")
        .to_ascii_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>();

    format!(
        "{:04x}:{:04x}:{:04x}:{}",
        id.vendor(),
        id.product(),
        id.version(),
        name_sanitized
    )
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

#[derive(Clone, Debug)]
struct SlotState {
    tracking_id: i32,
    x: f32,
    y: f32,
    active: bool,
    was_active: bool,
    dirty: bool,
}

impl Default for SlotState {
    fn default() -> Self {
        Self {
            tracking_id: -1,
            x: 0.0,
            y: 0.0,
            active: false,
            was_active: false,
            dirty: false,
        }
    }
}

pub struct DeviceManager {
    active_paths: Arc<Mutex<HashMap<PathBuf, String>>>,
}

impl DeviceManager {
    pub fn new() -> Self {
        Self {
            active_paths: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn start_discovery(&self) {
        let active = Arc::clone(&self.active_paths);

        thread::spawn(move || {
            let mut first_scan = true;

            loop {
                let mut found_any = false;
                let mut permission_denied = false;

                if let Ok(entries) = std::fs::read_dir("/dev/input") {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        let file_name = path
                            .file_name()
                            .and_then(|n| n.to_str())
                            .unwrap_or_default();

                        if !file_name.starts_with("event") {
                            continue;
                        }

                        let is_already_watched = {
                            let map = active.lock().unwrap();
                            map.contains_key(&path)
                        };

                        if is_already_watched {
                            found_any = true;
                            continue;
                        }

                        let dev = match Device::open(&path) {
                            Ok(d) => d,
                            Err(e) => {
                                if e.kind() == std::io::ErrorKind::PermissionDenied {
                                    permission_denied = true;
                                }
                                continue;
                            }
                        };

                        let name = dev.name().unwrap_or("unknown");
                        if is_virtual(name) {
                            continue;
                        }

                        if !is_touchscreen(&dev) {
                            continue;
                        }

                        let dev_id = stable_device_id(&dev);
                        found_any = true;

                        {
                            let mut map = active.lock().unwrap();
                            map.insert(path.clone(), dev_id.clone());
                        }

                        emit_event(&OutEvent::DeviceAdded {
                            device_id: dev_id.clone(),
                            name: name.to_string(),
                            path: path.to_string_lossy().to_string(),
                            kind: if is_stylus(&dev) { "pen" } else { "touch" }.to_string(),
                            is_desktop_mapped: is_desktop_mapped(&dev),
                        });

                        let active_clone = Arc::clone(&active);
                        let thread_path = path.clone();
                        let thread_id = dev_id.clone();

                        thread::spawn(move || {
                            let _ = watch_device(&thread_path, &thread_id);

                            {
                                let mut map = active_clone.lock().unwrap();
                                map.remove(&thread_path);
                            }

                            emit_event(&OutEvent::DeviceRemoved {
                                device_id: thread_id,
                            });
                        });
                    }
                }

                if first_scan {
                    first_scan = false;
                    if !found_any {
                        if permission_denied {
                            emit_event(&OutEvent::Status {
                                code: "permission_denied".to_string(),
                            });
                        } else {
                            emit_event(&OutEvent::Status {
                                code: "no_touchscreen".to_string(),
                            });
                        }
                    }
                }

                thread::sleep(Duration::from_secs(2));
            }
        });
    }
}

fn current_time_ms(time: Option<SystemTime>) -> u64 {
    time.unwrap_or_else(SystemTime::now)
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

fn watch_device(path: &Path, device_id: &str) -> std::io::Result<()> {
    let mut dev = Device::open(path)?;

    let is_multitouch = axis_range(&dev, AbsoluteAxisCode::ABS_MT_POSITION_X).is_some()
        || axis_range(&dev, AbsoluteAxisCode::ABS_MT_SLOT).is_some();

    let x_axis = if is_multitouch {
        AbsoluteAxisCode::ABS_MT_POSITION_X
    } else {
        AbsoluteAxisCode::ABS_X
    };

    let y_axis = if is_multitouch {
        AbsoluteAxisCode::ABS_MT_POSITION_Y
    } else {
        AbsoluteAxisCode::ABS_Y
    };

    let x_info = axis_range(&dev, x_axis);
    let y_info = axis_range(&dev, y_axis);

    let max_slots = dev
        .get_absinfo()
        .ok()
        .and_then(|mut iter| {
            iter.find(|(code, _)| *code == AbsoluteAxisCode::ABS_MT_SLOT)
                .map(|(_, info)| (info.maximum() + 1).max(1) as usize)
        })
        .unwrap_or(16);

    let mut slots: Vec<SlotState> = vec![SlotState::default(); max_slots];
    let mut current_slot = 0usize;

    // Single touch fallback state initialized to current coordinates
    let mut st_down = false;
    let mut st_x = dev
        .get_absinfo()
        .ok()
        .and_then(|mut i| {
            i.find(|(c, _)| *c == AbsoluteAxisCode::ABS_X)
                .map(|(_, info)| normalize(info.value(), Some(info)))
        })
        .unwrap_or(0.0);
    let mut st_y = dev
        .get_absinfo()
        .ok()
        .and_then(|mut i| {
            i.find(|(c, _)| *c == AbsoluteAxisCode::ABS_Y)
                .map(|(_, info)| normalize(info.value(), Some(info)))
        })
        .unwrap_or(0.0);
    let mut st_dirty = false;

    loop {
        for event in dev.fetch_events()? {
            let event_time = event.timestamp();

            match event.destructure() {
                EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_MT_SLOT, slot) => {
                    if (slot as usize) < slots.len() {
                        current_slot = slot as usize;
                    }
                }

                EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_MT_TRACKING_ID, id) => {
                    if current_slot < slots.len() {
                        let slot_data = &mut slots[current_slot];
                        slot_data.tracking_id = id;
                        slot_data.dirty = true;
                        if id >= 0 {
                            slot_data.active = true;
                        } else {
                            slot_data.active = false;
                        }
                    }
                }

                EventSummary::AbsoluteAxis(_, code, value) if code == x_axis => {
                    let norm_x = normalize(value, x_info);
                    if is_multitouch {
                        if current_slot < slots.len() {
                            slots[current_slot].x = norm_x;
                            slots[current_slot].dirty = true;
                        }
                    } else {
                        st_x = norm_x;
                        st_dirty = true;
                    }
                }

                EventSummary::AbsoluteAxis(_, code, value) if code == y_axis => {
                    let norm_y = normalize(value, y_info);
                    if is_multitouch {
                        if current_slot < slots.len() {
                            slots[current_slot].y = norm_y;
                            slots[current_slot].dirty = true;
                        }
                    } else {
                        st_y = norm_y;
                        st_dirty = true;
                    }
                }

                EventSummary::Key(_, code, val)
                    if code == KeyCode::BTN_TOUCH || code == KeyCode::BTN_LEFT =>
                {
                    if !is_multitouch {
                        let now = current_time_ms(Some(event_time));
                        if val == 1 {
                            st_down = true;
                            emit_event(&OutEvent::TouchDown {
                                device_id: device_id.to_string(),
                                contact_id: 0,
                                x: st_x,
                                y: st_y,
                                time: now,
                            });
                        } else if val == 0 {
                            st_down = false;
                            emit_event(&OutEvent::TouchUp {
                                device_id: device_id.to_string(),
                                contact_id: 0,
                                x: st_x,
                                y: st_y,
                                time: now,
                            });
                        }
                    }
                }

                EventSummary::Synchronization(_, evdev::SynchronizationCode::SYN_REPORT, _) => {
                    let now = current_time_ms(Some(event_time));

                    if is_multitouch {
                        for (idx, slot) in slots.iter_mut().enumerate() {
                            if !slot.dirty {
                                continue;
                            }
                            slot.dirty = false;

                            // The slot index is the contact identity in MT protocol B.
                            // ABS_MT_TRACKING_ID is cleared to -1 before the SYN_REPORT that
                            // ends a contact, so keying on it would emit touch_up under a
                            // different id than the matching touch_down.
                            let contact_id = idx as i32;

                            if slot.active && !slot.was_active {
                                // Touch Down
                                slot.was_active = true;
                                emit_event(&OutEvent::TouchDown {
                                    device_id: device_id.to_string(),
                                    contact_id,
                                    x: slot.x,
                                    y: slot.y,
                                    time: now,
                                });
                            } else if !slot.active && slot.was_active {
                                // Touch Up
                                slot.was_active = false;
                                emit_event(&OutEvent::TouchUp {
                                    device_id: device_id.to_string(),
                                    contact_id,
                                    x: slot.x,
                                    y: slot.y,
                                    time: now,
                                });
                            } else if slot.active && slot.was_active {
                                // Touch Move
                                emit_event(&OutEvent::TouchMove {
                                    device_id: device_id.to_string(),
                                    contact_id,
                                    x: slot.x,
                                    y: slot.y,
                                    time: now,
                                });
                            }
                        }
                    } else if st_down && st_dirty {
                        st_dirty = false;
                        emit_event(&OutEvent::TouchMove {
                            device_id: device_id.to_string(),
                            contact_id: 0,
                            x: st_x,
                            y: st_y,
                            time: now,
                        });
                    }
                }

                _ => {}
            }
        }
    }
}
