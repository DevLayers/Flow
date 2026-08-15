use std::collections::HashMap;
use std::io::{self, BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use futures_util::StreamExt;
use tokio::time::{sleep, Duration};
use zbus::{proxy, zvariant::{OwnedValue, Value}, Connection};
use zbus::fdo::DBusProxy;

use crate::error::BridgeError;
use crate::protocol::{DisplayItem, ManagerEvent, NetworkDisplayProtocol};

pub const MANAGER_BUS_NAME: &str = "org.gnome.NetworkDisplays.Manager";
pub const MANAGER_OBJECT_PATH: &str = "/org/gnome/NetworkDisplays/Manager";
pub const MANAGER_INTERFACE: &str = "org.gnome.NetworkDisplays.Manager";

#[proxy(
    default_service = "org.gnome.NetworkDisplays.Manager",
    default_path = "/org/gnome/NetworkDisplays/Manager",
    interface = "org.gnome.NetworkDisplays.Manager"
)]
pub trait NetworkDisplaysManager {
    #[zbus(property)]
    fn displays(&self) -> zbus::Result<Vec<HashMap<String, OwnedValue>>>;

    #[zbus(name = "StartStream")]
    fn start_stream(&self, sink_uuid: &str) -> zbus::Result<String>;

    #[zbus(name = "StopStream")]
    fn stop_stream(&self, stream_unit_name: &str) -> zbus::Result<()>;
}

fn get_string(val: &OwnedValue) -> Option<String> {
    match &**val {
        Value::Str(s) => Some(s.as_str().to_string()),
        _ => None,
    }
}

fn get_u32(val: &OwnedValue) -> u32 {
    match &**val {
        Value::U32(n) => *n,
        Value::I32(n) => *n as u32,
        Value::U64(n) => *n as u32,
        Value::I64(n) => *n as u32,
        Value::U16(n) => *n as u32,
        Value::I16(n) => *n as u32,
        Value::U8(n) => *n as u32,
        _ => 0,
    }
}

pub fn parse_display_dict(dict: &HashMap<String, OwnedValue>) -> Option<DisplayItem> {
    let uuid = match dict.get("uuid").and_then(get_string) {
        Some(s) => s,
        None => return None,
    };

    let name = dict.get("display-name").and_then(get_string).unwrap_or_else(|| uuid.clone());
    let priority = dict.get("priority").map(get_u32).unwrap_or(0);
    let state = dict.get("state").map(get_u32).unwrap_or(0);
    let protocol_num = dict.get("protocol").map(get_u32).unwrap_or(0);

    let protocol_enum = NetworkDisplayProtocol::from_u32(protocol_num);

    Some(DisplayItem {
        uuid,
        name,
        priority,
        state,
        protocol: protocol_enum.as_str().to_string(),
        address: None,
        port: None,
        model: None,
    })
}

fn emit_json<T: serde::Serialize>(val: &T) {
    if let Ok(json) = serde_json::to_string(val) {
        let mut stdout = io::stdout().lock();
        let _ = writeln!(stdout, "{}", json);
        let _ = stdout.flush();
    }
}

/// Parses an Avahi parseable line (=;interface;protocol;name;type;domain;hostname;address;port;txt)
pub fn parse_avahi_line(line: &str) -> Option<DisplayItem> {
    let parts: Vec<&str> = line.split(';').collect();
    if parts.len() < 9 || parts[0] != "=" {
        return None;
    }

    let service_name = parts[3];
    let service_type = parts[4];
    let hostname = parts[6];
    let address = parts[7].to_string();
    let port = parts[8].parse::<u16>().ok();
    let txt = if parts.len() > 9 { parts[9..].join(";") } else { String::new() };

    let mut fn_val: Option<String> = None;
    let mut md_val: Option<String> = None;
    let mut id_val: Option<String> = None;

    // Parse txt tokens: "key=value" or "key"
    for token in txt.split('"') {
        let token = token.trim();
        if token.is_empty() {
            continue;
        }
        if let Some(rest) = token.strip_prefix("fn=") {
            fn_val = Some(rest.trim().to_string());
        } else if let Some(rest) = token.strip_prefix("md=") {
            md_val = Some(rest.trim().to_string());
        } else if let Some(rest) = token.strip_prefix("id=") {
            id_val = Some(rest.trim().to_string());
        }
    }

    let (protocol, priority) = match service_type {
        "_googlecast._tcp" => ("chromecast", 100),
        "_display._tcp" => ("miracastMice", 90),
        "_airplay._tcp" | "_raop._tcp" => ("airplay", 80),
        _ => ("unknown", 50),
    };

    let display_name = match (&fn_val, &md_val) {
        (Some(f), Some(m)) if !m.is_empty() && !f.ends_with(m) => format!("{} - {}", f, m),
        (Some(f), _) => f.clone(),
        (None, Some(m)) => format!("{} ({})", service_name, m),
        (None, None) => service_name.to_string(),
    };

    let uuid = id_val.unwrap_or_else(|| {
        if !address.is_empty() {
            format!("{}:{}", address, port.unwrap_or(8009))
        } else {
            service_name.to_string()
        }
    });

    Some(DisplayItem {
        uuid,
        name: display_name,
        priority,
        state: 0,
        protocol: protocol.to_string(),
        address: Some(address),
        port,
        model: md_val,
    })
}

/// Runs a one-shot Avahi mDNS scan for supported services
pub fn scan_avahi_once() -> Vec<DisplayItem> {
    let mut results = HashMap::new();

    for service in ["_googlecast._tcp", "_display._tcp", "_airplay._tcp"] {
        if let Ok(output) = Command::new("avahi-browse")
            .args(["-r", "-t", "-p", service])
            .output()
        {
            if let Ok(text) = String::from_utf8(output.stdout) {
                for line in text.lines() {
                    if let Some(item) = parse_avahi_line(line) {
                        results.insert(item.uuid.clone(), item);
                    }
                }
            }
        }
    }

    let mut list: Vec<DisplayItem> = results.into_values().collect();
    list.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| a.name.cmp(&b.name)));
    list
}

pub async fn list_displays() -> Result<Vec<DisplayItem>, BridgeError> {
    let mut all_displays = HashMap::new();

    // 1. Scan Avahi mDNS
    for item in scan_avahi_once() {
        all_displays.insert(item.uuid.clone(), item);
    }

    // 2. Query GNOME Network Displays D-Bus if available
    if let Ok(connection) = Connection::session().await {
        if let Ok(dbus) = DBusProxy::new(&connection).await {
            if let Ok(has_owner) = dbus.name_has_owner(MANAGER_BUS_NAME.try_into().unwrap()).await {
                if has_owner {
                    if let Ok(proxy) = NetworkDisplaysManagerProxy::new(&connection).await {
                        if let Ok(raw) = proxy.displays().await {
                            for dict in raw {
                                if let Some(item) = parse_display_dict(&dict) {
                                    all_displays.insert(item.uuid.clone(), item);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    let mut list: Vec<DisplayItem> = all_displays.into_values().collect();
    list.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| a.name.cmp(&b.name)));
    Ok(list)
}

pub async fn start_stream(uuid: &str) -> Result<String, BridgeError> {
    if uuid.trim().is_empty() || uuid.len() > 256 || uuid.contains('\0') {
        return Err(BridgeError::invalid_args("Invalid UUID provided"));
    }

    // 1. Find device in Avahi scanned devices
    let displays = scan_avahi_once();
    let found = displays.into_iter().find(|d| d.uuid == uuid || uuid.contains(&d.uuid));

    if let Some(target) = found {
        if target.protocol == "chromecast" || target.address.is_some() {
            let ip = target.address.unwrap_or_else(|| "127.0.0.1".to_string());
            let port = target.port.unwrap_or(8009);

            let streamer_script = "/home/pedro/.config/quickshell/ii/scripts/networkDisplays/chromecast_streamer.py";
            let child = Command::new("python3")
                .args([streamer_script, "start", "--ip", &ip, "--port", &port.to_string()])
                .spawn();

            match child {
                Ok(_) => {
                    return Ok(format!("cast-{}", uuid));
                }
                Err(e) => {
                    return Err(BridgeError::start_stream_failed(format!("Failed to start chromecast streamer: {}", e)));
                }
            }
        }
    }

    // 2. Check if GNOME Network Displays manager is running on D-Bus
    if let Ok(connection) = Connection::session().await {
        if let Ok(proxy) = NetworkDisplaysManagerProxy::new(&connection).await {
            if let Ok(stream_unit) = proxy.start_stream(uuid).await {
                return Ok(stream_unit);
            }
        }
    }

    // 3. Headless service mode (no GUI window!)
    let _ = Command::new("flatpak")
        .args(["run", "org.gnome.NetworkDisplays", "--gapplication-service"])
        .spawn();

    Ok(format!("stream-{}", uuid))
}

pub async fn stop_stream(unit_name: &str) -> Result<(), BridgeError> {
    // 1. Stop native chromecast streamer
    let streamer_script = "/home/pedro/.config/quickshell/ii/scripts/networkDisplays/chromecast_streamer.py";
    let _ = Command::new("python3")
        .args([streamer_script, "stop"])
        .status();

    // 2. Try GNOME Network Displays D-Bus
    if let Ok(connection) = Connection::session().await {
        if let Ok(proxy) = NetworkDisplaysManagerProxy::new(&connection).await {
            let _ = proxy.stop_stream(unit_name).await;
        }
    }

    // 3. Fallback to systemd safe stop
    crate::systemd::stop_unit_safe(unit_name).await
}

pub async fn watch_manager() -> Result<(), BridgeError> {
    emit_json(&ManagerEvent::BridgeReady { version: 1 });
    emit_json(&ManagerEvent::ManagerAvailable {
        owner: "network-display-bridge".to_string(),
    });

    let display_store: Arc<Mutex<HashMap<String, DisplayItem>>> = Arc::new(Mutex::new(HashMap::new()));

    // Initial snapshot
    {
        let initial = scan_avahi_once();
        let mut store = display_store.lock().unwrap();
        for item in &initial {
            store.insert(item.uuid.clone(), item.clone());
        }
        let list: Vec<DisplayItem> = store.values().cloned().collect();
        emit_json(&ManagerEvent::DisplaysSnapshot { displays: list });
    }

    // Continuous avahi-browse streaming child process
    let store_clone = Arc::clone(&display_store);
    tokio::task::spawn_blocking(move || {
        loop {
            let mut child = match Command::new("avahi-browse")
                .args(["-r", "-p", "_googlecast._tcp", "_display._tcp", "_airplay._tcp"])
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn()
            {
                Ok(c) => c,
                Err(_) => {
                    std::thread::sleep(Duration::from_secs(5));
                    continue;
                }
            };

            if let Some(stdout) = child.stdout.take() {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(l) = line {
                        let l_trimmed = l.trim();
                        if l_trimmed.starts_with('=') {
                            if let Some(item) = parse_avahi_line(l_trimmed) {
                                let mut store = store_clone.lock().unwrap();
                                store.insert(item.uuid.clone(), item);
                                let mut list: Vec<DisplayItem> = store.values().cloned().collect();
                                list.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| a.name.cmp(&b.name)));
                                emit_json(&ManagerEvent::DisplaysSnapshot { displays: list });
                            }
                        } else if l_trimmed.starts_with('-') {
                            let parts: Vec<&str> = l_trimmed.split(';').collect();
                            if parts.len() > 3 {
                                let svc_name = parts[3];
                                let mut store = store_clone.lock().unwrap();
                                store.retain(|_, v| !v.name.contains(svc_name) && v.uuid != svc_name);
                                let mut list: Vec<DisplayItem> = store.values().cloned().collect();
                                list.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| a.name.cmp(&b.name)));
                                emit_json(&ManagerEvent::DisplaysSnapshot { displays: list });
                            }
                        }
                    }
                }
            }

            let _ = child.wait();
            std::thread::sleep(Duration::from_secs(3));
        }
    });

    // Periodic snapshot broadcast loop
    loop {
        sleep(Duration::from_secs(10)).await;
        let mut store = display_store.lock().unwrap();
        // Periodically refresh list
        for item in scan_avahi_once() {
            store.insert(item.uuid.clone(), item);
        }
        let mut list: Vec<DisplayItem> = store.values().cloned().collect();
        list.sort_by(|a, b| b.priority.cmp(&a.priority).then_with(|| a.name.cmp(&b.name)));
        emit_json(&ManagerEvent::DisplaysSnapshot { displays: list });
    }
}
