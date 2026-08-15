mod diagnostics;
mod error;
mod manager;
mod protocol;
mod systemd;

use std::env;
use std::io::{self, Write};
use protocol::{ListResponse, StartResponse, StopResponse};

fn emit_json<T: serde::Serialize>(val: &T) {
    if let Ok(json) = serde_json::to_string(val) {
        let mut stdout = io::stdout().lock();
        let _ = writeln!(stdout, "{}", json);
        let _ = stdout.flush();
    }
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: network_display_bridge <manager-watch|list|start <uuid>|stop <unit>|unit-watch <unit>|diagnose>");
        std::process::exit(1);
    }

    let subcommand = args[1].as_str();

    match subcommand {
        "manager-watch" => {
            if let Err(e) = manager::watch_manager().await {
                eprintln!("[network-display-bridge] Watcher exited with error: {}", e);
                std::process::exit(1);
            }
        }
        "list" => {
            match manager::list_displays().await {
                Ok(displays) => {
                    emit_json(&ListResponse {
                        ok: true,
                        displays: Some(displays),
                        error: None,
                        message: None,
                    });
                }
                Err(e) => {
                    emit_json(&ListResponse {
                        ok: false,
                        displays: None,
                        error: Some(e.code.to_string()),
                        message: Some(e.message),
                    });
                }
            }
        }
        "start" => {
            if args.len() < 3 {
                emit_json(&StartResponse {
                    ok: false,
                    uuid: None,
                    stream_unit: None,
                    error: Some("invalidArguments".to_string()),
                    message: Some("Missing sink UUID argument".to_string()),
                });
                std::process::exit(1);
            }
            let uuid = &args[2];
            match manager::start_stream(uuid).await {
                Ok(unit) => {
                    emit_json(&StartResponse {
                        ok: true,
                        uuid: Some(uuid.to_string()),
                        stream_unit: Some(unit),
                        error: None,
                        message: None,
                    });
                }
                Err(e) => {
                    emit_json(&StartResponse {
                        ok: false,
                        uuid: Some(uuid.to_string()),
                        stream_unit: None,
                        error: Some(e.code.to_string()),
                        message: Some(e.message),
                    });
                }
            }
        }
        "stop" => {
            if args.len() < 3 {
                emit_json(&StopResponse {
                    ok: false,
                    stream_unit: None,
                    error: Some("invalidArguments".to_string()),
                    message: Some("Missing stream unit argument".to_string()),
                });
                std::process::exit(1);
            }
            let unit = &args[2];
            match manager::stop_stream(unit).await {
                Ok(()) => {
                    emit_json(&StopResponse {
                        ok: true,
                        stream_unit: Some(unit.to_string()),
                        error: None,
                        message: None,
                    });
                }
                Err(e) => {
                    emit_json(&StopResponse {
                        ok: false,
                        stream_unit: Some(unit.to_string()),
                        error: Some(e.code.to_string()),
                        message: Some(e.message),
                    });
                }
            }
        }
        "unit-watch" => {
            if args.len() < 3 {
                eprintln!("[network-display-bridge] Missing unit argument for unit-watch");
                std::process::exit(1);
            }
            let unit = &args[2];
            if let Err(e) = systemd::watch_unit(unit).await {
                eprintln!("[network-display-bridge] unit-watch error: {}", e);
                std::process::exit(1);
            }
        }
        "diagnose" => {
            let report = diagnostics::run_diagnostics().await;
            emit_json(&report);
        }
        other => {
            eprintln!("[network-display-bridge] Unknown subcommand: {}", other);
            std::process::exit(1);
        }
    }
}
