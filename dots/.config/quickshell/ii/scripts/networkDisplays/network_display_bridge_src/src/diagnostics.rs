use std::path::Path;
use std::process::Command;
use zbus::fdo::DBusProxy;
use zbus::Connection;

use crate::manager::MANAGER_BUS_NAME;
use crate::protocol::{
    BackendDiag, BridgeDiag, CodecsDiag, DiagnoseReport, NetworkManagerDiag, PipewireDiag,
    PortalDiag,
};

pub async fn run_diagnostics() -> DiagnoseReport {
    // 1. Bridge
    let bridge = BridgeDiag {
        ok: true,
        version: 1,
    };

    // 2. Backend (gnome-network-displays binary/flatpak & session D-Bus manager)
    let (daemon_binary, daemon_path) = check_backend_binary();

    let mut manager_bus = false;
    let mut manager_owner = None;

    let session_conn = Connection::session().await.ok();
    if let Some(ref conn) = session_conn {
        if let Ok(dbus) = DBusProxy::new(conn).await {
            if let Ok(owner) = dbus.get_name_owner(MANAGER_BUS_NAME.try_into().unwrap()).await {
                manager_bus = true;
                manager_owner = Some(owner.to_string());
            } else if let Ok(owner) = dbus.get_name_owner("org.gnome.NetworkDisplays".try_into().unwrap()).await {
                manager_bus = true;
                manager_owner = Some(owner.to_string());
            }
        }
    }

    let backend = BackendDiag {
        daemon_binary,
        daemon_path,
        manager_bus,
        manager_owner,
    };

    // 3. Portal
    let mut desktop_portal = false;
    let mut screen_cast = false;
    let hyprland_backend = check_binary("xdg-desktop-portal-hyprland").0;

    if let Some(ref conn) = session_conn {
        if let Ok(dbus) = DBusProxy::new(conn).await {
            if let Ok(has_portal) = dbus.name_has_owner("org.freedesktop.portal.Desktop".try_into().unwrap()).await {
                desktop_portal = has_portal;
            }
        }
        // Check if ScreenCast interface is available
        if desktop_portal {
            screen_cast = true; // org.freedesktop.portal.Desktop provides ScreenCast portal
        }
    }

    let portal = PortalDiag {
        desktop_portal,
        screen_cast,
        hyprland_backend,
    };

    // 4. PipeWire
    let mut socket_exists = false;
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        let pw_sock = Path::new(&runtime_dir).join("pipewire-0");
        if pw_sock.exists() {
            socket_exists = true;
        }
    }

    let mut pw_cli_avail = false;
    if check_binary("pw-cli").0 {
        if let Ok(status) = Command::new("pw-cli").arg("info").arg("0").output() {
            pw_cli_avail = status.status.success();
        }
    }

    let pipewire = PipewireDiag {
        available: socket_exists || pw_cli_avail,
        socket_exists,
    };

    // 5. NetworkManager
    let mut nm_available = false;
    let mut wifi_device = false;
    let mut p2p_device = false;

    let system_conn = Connection::system().await.ok();
    if let Some(ref conn) = system_conn {
        if let Ok(dbus) = DBusProxy::new(conn).await {
            if let Ok(has_nm) = dbus.name_has_owner("org.freedesktop.NetworkManager".try_into().unwrap()).await {
                nm_available = has_nm;
            }
        }
    }

    // Check wifi and p2p devices via nmcli if installed
    if check_binary("nmcli").0 {
        if let Ok(output) = Command::new("nmcli").arg("-t").arg("-f").arg("DEVICE,TYPE").arg("device").output() {
            let out_str = String::from_utf8_lossy(&output.stdout);
            for line in out_str.lines() {
                let parts: Vec<&str> = line.split(':').collect();
                if parts.len() >= 2 {
                    let dev = parts[0];
                    let dev_type = parts[1];
                    if dev_type == "wifi" {
                        wifi_device = true;
                    }
                    if dev.starts_with("p2p-dev-") || dev_type == "wifi-p2p" {
                        p2p_device = true;
                    }
                }
            }
        }
    }

    let network_manager = NetworkManagerDiag {
        available: nm_available,
        wifi_device,
        p2p_device,
    };

    // 6. Codecs (H.264 and AAC)
    let mut h264_encoders = Vec::new();
    let mut aac_encoders = Vec::new();

    if check_binary("gst-inspect-1.0").0 {
        let h264_candidates = [
            "vah264enc",
            "vaapih264enc",
            "nvh264enc",
            "x264enc",
            "openh264enc",
            "v4l2h264enc",
            "msdkh264enc",
        ];
        let aac_candidates = ["avenc_aac", "faac", "fdkaacenc", "voaacenc"];

        for cand in &h264_candidates {
            if check_gst_element(cand) {
                h264_encoders.push(cand.to_string());
            }
        }

        for cand in &aac_candidates {
            if check_gst_element(cand) {
                aac_encoders.push(cand.to_string());
            }
        }
    }

    let codecs = CodecsDiag {
        h264: h264_encoders,
        aac: aac_encoders,
    };

    let overall_ok = bridge.ok;

    DiagnoseReport {
        ok: overall_ok,
        bridge,
        backend,
        portal,
        pipewire,
        network_manager,
        codecs,
    }
}

fn check_backend_binary() -> (bool, Option<String>) {
    let (found, path) = check_binary("gnome-network-displays-daemon");
    if found {
        return (true, path);
    }
    let (found, path) = check_binary("gnome-network-displays");
    if found {
        return (true, path);
    }
    if let Ok(output) = Command::new("flatpak").args(["info", "org.gnome.NetworkDisplays"]).output() {
        if output.status.success() {
            return (true, Some("flatpak:org.gnome.NetworkDisplays".to_string()));
        }
    }
    (false, None)
}

fn check_binary(name: &str) -> (bool, Option<String>) {
    if let Ok(output) = Command::new("which").arg(name).output() {
        if output.status.success() {
            let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
            return (true, Some(path));
        }
    }
    (false, None)
}

fn check_gst_element(element: &str) -> bool {
    if let Ok(output) = Command::new("gst-inspect-1.0").arg(element).output() {
        output.status.success()
    } else {
        false
    }
}
