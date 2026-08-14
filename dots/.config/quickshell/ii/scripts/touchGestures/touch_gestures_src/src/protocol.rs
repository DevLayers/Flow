use serde::Serialize;
use std::io::Write;
use std::sync::Mutex;

static STDOUT_LOCK: Mutex<()> = Mutex::new(());

#[allow(dead_code)]
#[derive(Serialize, Debug, Clone)]
#[serde(tag = "type")]
pub enum OutEvent {
    #[serde(rename = "ready")]
    Ready { version: u32 },

    #[serde(rename = "device_added")]
    DeviceAdded {
        #[serde(rename = "deviceId")]
        device_id: String,
        name: String,
        path: String,
        /// "touch" for fingers, "pen" for stylus/digitizer devices.
        kind: String,
        #[serde(rename = "isDesktopMapped", default)]
        is_desktop_mapped: bool,
    },

    #[serde(rename = "device_removed")]
    DeviceRemoved {
        #[serde(rename = "deviceId")]
        device_id: String,
    },

    #[serde(rename = "touch_down")]
    TouchDown {
        #[serde(rename = "deviceId")]
        device_id: String,
        #[serde(rename = "contactId")]
        contact_id: i32,
        x: f32,
        y: f32,
        time: u64,
    },

    #[serde(rename = "touch_move")]
    TouchMove {
        #[serde(rename = "deviceId")]
        device_id: String,
        #[serde(rename = "contactId")]
        contact_id: i32,
        x: f32,
        y: f32,
        time: u64,
    },

    #[serde(rename = "touch_up")]
    TouchUp {
        #[serde(rename = "deviceId")]
        device_id: String,
        #[serde(rename = "contactId")]
        contact_id: i32,
        x: f32,
        y: f32,
        time: u64,
    },

    #[serde(rename = "touch_cancel")]
    TouchCancel {
        #[serde(rename = "deviceId")]
        device_id: String,
        #[serde(rename = "contactId")]
        contact_id: i32,
        time: u64,
    },

    #[serde(rename = "status")]
    Status { code: String },

    #[serde(rename = "error")]
    Error {
        code: String,
        message: String,
    },
}

pub fn emit_event(event: &OutEvent) {
    if let Ok(_guard) = STDOUT_LOCK.lock() {
        if let Ok(json) = serde_json::to_string(event) {
            println!("{}", json);
            let _ = std::io::stdout().flush();
        }
    }
}
