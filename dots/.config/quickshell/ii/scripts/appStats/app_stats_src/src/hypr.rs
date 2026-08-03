//! Hyprland IPC: window state on demand, transitions as they happen.
//!
//! `.socket.sock` answers one request per connection; `.socket2.sock` is a
//! long-lived event stream. Splitting the two is the whole reason the sampler can
//! poll counters only six times a minute and still record a window switch exactly:
//! transitions arrive as events, and nothing about them needs polling.

use std::env;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::sync::mpsc::Sender;

pub struct Client {
    pub pid: u32,
    pub class: String,
    pub visible: bool,
    pub focused: bool,
}

fn socket_dir() -> Option<PathBuf> {
    let runtime = env::var("XDG_RUNTIME_DIR").ok()?;
    let sig = env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    Some(PathBuf::from(runtime).join("hypr").join(sig))
}

fn request(cmd: &str) -> Option<String> {
    let mut sock = UnixStream::connect(socket_dir()?.join(".socket.sock")).ok()?;
    sock.write_all(cmd.as_bytes()).ok()?;
    let mut out = String::new();
    sock.read_to_string(&mut out).ok()?;
    Some(out)
}

fn json(cmd: &str) -> Option<serde_json::Value> {
    serde_json::from_str(&request(cmd)?).ok()
}

/// Workspace ids currently on a powered-on monitor. A client's own `visible` field
/// is *not* this: Hyprland reports every mapped, unhidden window as visible
/// regardless of which workspace it sits on, so a browser three workspaces away
/// would otherwise accrue foreground time forever.
fn onscreen_workspaces() -> Vec<i64> {
    let Some(arr) = json("j/monitors").and_then(|v| v.as_array().cloned()) else {
        return Vec::new();
    };
    let mut ids = Vec::new();
    for m in &arr {
        if m.get("disabled").and_then(|v| v.as_bool()).unwrap_or(false) {
            continue;
        }
        // A blanked monitor shows nothing, so nothing on it is foreground.
        if !m.get("dpmsStatus").and_then(|v| v.as_bool()).unwrap_or(true) {
            continue;
        }
        for field in ["activeWorkspace", "specialWorkspace"] {
            if let Some(id) = m.get(field).and_then(|w| w.get("id")).and_then(|v| v.as_i64()) {
                // A special workspace overlays the normal one rather than replacing
                // it, so both count; id 0 means no special workspace is open.
                if id != 0 {
                    ids.push(id);
                }
            }
        }
    }
    ids
}

pub fn clients() -> Vec<Client> {
    let onscreen = onscreen_workspaces();
    let Some(arr) = json("j/clients").and_then(|v| v.as_array().cloned()) else {
        return Vec::new();
    };

    arr.iter()
        .filter_map(|c| {
            let pid = c.get("pid")?.as_u64()? as u32;
            if pid == 0 {
                return None;
            }
            let class = c.get("class")?.as_str().unwrap_or("").to_string();
            let mapped = c.get("mapped").and_then(|v| v.as_bool()).unwrap_or(true);
            let hidden = c.get("hidden").and_then(|v| v.as_bool()).unwrap_or(false);
            let ws = c
                .get("workspace")
                .and_then(|w| w.get("id"))
                .and_then(|v| v.as_i64())
                .unwrap_or(i64::MIN);
            // A pinned window follows the user across workspaces and is always on screen.
            let pinned = c.get("pinned").and_then(|v| v.as_bool()).unwrap_or(false);

            Some(Client {
                visible: mapped && !hidden && (pinned || onscreen.contains(&ws)),
                focused: c.get("focusHistoryID").and_then(|v| v.as_i64()) == Some(0),
                pid,
                class,
            })
        })
        .filter(|c| !c.class.is_empty())
        .collect()
}

/// Events that can change which windows exist or which are on screen. Anything
/// else on the stream (titles, submaps, audio) would only cause a needless requery.
fn is_interesting(event: &str) -> bool {
    matches!(
        event,
        "openwindow"
            | "closewindow"
            | "movewindow"
            | "movewindowv2"
            | "activewindow"
            | "activewindowv2"
            | "workspace"
            | "workspacev2"
            | "focusedmon"
            | "focusedmonv2"
            | "monitoradded"
            | "monitorremoved"
            | "fullscreen"
            | "changefloatingmode"
            | "movetoworkspace"
            | "movetoworkspacev2"
    )
}

/// Subscribe to the event stream, notifying `tx` whenever window state may have
/// changed. Reconnects on its own: Hyprland closing the socket must not silently
/// freeze collection at whatever the last known window layout was.
pub fn watch(tx: Sender<crate::Msg>) {
    loop {
        let path = match socket_dir() {
            Some(d) => d.join(".socket2.sock"),
            None => return,
        };

        if let Ok(sock) = UnixStream::connect(&path) {
            let reader = BufReader::new(sock);
            for line in reader.lines().map_while(Result::ok) {
                let event = line.split_once(">>").map(|(e, _)| e).unwrap_or(&line);
                if is_interesting(event) && tx.send(crate::Msg::WindowsChanged).is_err() {
                    return;
                }
            }
        }

        if tx.send(crate::Msg::WindowsChanged).is_err() {
            return;
        }
        std::thread::sleep(std::time::Duration::from_secs(2));
    }
}
