use std::io::{self, Write};
use futures_util::StreamExt;
use zbus::{proxy, zvariant::OwnedObjectPath, Connection};

use crate::error::BridgeError;
use crate::protocol::UnitWatchEvent;

pub const SYSTEMD_BUS_NAME: &str = "org.freedesktop.systemd1";
pub const SYSTEMD_OBJECT_PATH: &str = "/org/freedesktop/systemd1";

pub fn validate_stream_unit_name(unit: &str) -> Result<(), BridgeError> {
    let u = unit.trim();
    if !u.starts_with("gnome-network-displays-stream-") || !u.ends_with(".service") {
        return Err(BridgeError::invalid_args(format!(
            "Invalid stream unit name: '{}'. Must start with 'gnome-network-displays-stream-' and end with '.service'",
            unit
        )));
    }
    if u.contains('/') || u.contains('\\') || u.contains('\0') {
        return Err(BridgeError::invalid_args("Stream unit name contains invalid path characters"));
    }
    Ok(())
}

#[proxy(
    default_service = "org.freedesktop.systemd1",
    default_path = "/org/freedesktop/systemd1",
    interface = "org.freedesktop.systemd1.Manager"
)]
pub trait SystemdManager {
    #[zbus(name = "GetUnit")]
    fn get_unit(&self, name: &str) -> zbus::Result<OwnedObjectPath>;

    #[zbus(name = "LoadUnit")]
    fn load_unit(&self, name: &str) -> zbus::Result<OwnedObjectPath>;

    #[zbus(name = "StopUnit")]
    fn stop_unit(&self, name: &str, mode: &str) -> zbus::Result<OwnedObjectPath>;
}

#[proxy(
    default_service = "org.freedesktop.systemd1",
    interface = "org.freedesktop.systemd1.Unit"
)]
pub trait SystemdUnit {
    #[zbus(property)]
    fn active_state(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn sub_state(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn load_state(&self) -> zbus::Result<String>;
}

fn emit_json<T: serde::Serialize>(val: &T) {
    if let Ok(json) = serde_json::to_string(val) {
        let mut stdout = io::stdout().lock();
        let _ = writeln!(stdout, "{}", json);
        let _ = stdout.flush();
    }
}

pub async fn stop_unit_safe(unit_name: &str) -> Result<(), BridgeError> {
    validate_stream_unit_name(unit_name)?;

    let connection = Connection::session()
        .await
        .map_err(|e| BridgeError::dbus_failed(format!("Failed to connect to user session bus: {}", e)))?;

    let manager_proxy = SystemdManagerProxy::new(&connection)
        .await
        .map_err(|e| BridgeError::dbus_failed(format!("Failed to create systemd manager proxy: {}", e)))?;

    manager_proxy
        .stop_unit(unit_name, "replace")
        .await
        .map_err(|e| BridgeError::stop_stream_failed(format!("Systemd StopUnit failed: {}", e)))?;

    Ok(())
}

pub async fn watch_unit(unit_name: &str) -> Result<(), BridgeError> {
    validate_stream_unit_name(unit_name)?;

    let connection = Connection::session()
        .await
        .map_err(|e| BridgeError::dbus_failed(format!("Failed to connect to user session bus: {}", e)))?;

    let manager_proxy = SystemdManagerProxy::new(&connection)
        .await
        .map_err(|e| BridgeError::dbus_failed(format!("Failed to create systemd manager proxy: {}", e)))?;

    let unit_path = match manager_proxy.get_unit(unit_name).await {
        Ok(path) => path,
        Err(_) => manager_proxy
            .load_unit(unit_name)
            .await
            .map_err(|e| BridgeError::unit_failed(format!("Failed to find or load unit '{}': {}", unit_name, e)))?,
    };

    let unit_proxy = SystemdUnitProxy::builder(&connection)
        .path(unit_path)?
        .build()
        .await
        .map_err(|e| BridgeError::unit_failed(format!("Failed to create unit proxy: {}", e)))?;

    // Initial state
    let active_state = unit_proxy.active_state().await.unwrap_or_else(|_| "unknown".to_string());
    let sub_state = unit_proxy.sub_state().await.unwrap_or_else(|_| "unknown".to_string());

    emit_json(&UnitWatchEvent::UnitState {
        unit: unit_name.to_string(),
        active_state: active_state.clone(),
        sub_state: sub_state.clone(),
    });

    if active_state == "failed" || active_state == "inactive" {
        return Ok(());
    }

    let mut active_state_stream = unit_proxy.receive_active_state_changed().await;
    let mut sub_state_stream = unit_proxy.receive_sub_state_changed().await;

    let mut current_active = active_state;
    let mut current_sub = sub_state;

    loop {
        tokio::select! {
            Some(active_change) = active_state_stream.next() => {
                if let Ok(new_active) = active_change.get().await {
                    current_active = new_active;
                    emit_json(&UnitWatchEvent::UnitState {
                        unit: unit_name.to_string(),
                        active_state: current_active.clone(),
                        sub_state: current_sub.clone(),
                    });

                    if current_active == "failed" || current_active == "inactive" {
                        break;
                    }
                }
            }
            Some(sub_change) = sub_state_stream.next() => {
                if let Ok(new_sub) = sub_change.get().await {
                    current_sub = new_sub;
                    emit_json(&UnitWatchEvent::UnitState {
                        unit: unit_name.to_string(),
                        active_state: current_active.clone(),
                        sub_state: current_sub.clone(),
                    });
                }
            }
            _ = tokio::signal::ctrl_c() => {
                break;
            }
            else => break,
        }
    }

    Ok(())
}
