# Network Display Bridge

Bridge helper in Rust for communicating with the GNOME Network Displays daemon and managing remote casting (Miracast / Wi-Fi Direct, MICE, Chromecast) within Quickshell / ii.

## Purpose

Provides event-driven session D-Bus communication without polling:
- Watches `org.gnome.NetworkDisplays.Manager` for receiver discovery.
- Starts/stops cast streams via `StartStream` and `StopStream`.
- Monitors transient systemd stream unit lifecycles via user systemd D-Bus.
- Emits clean JSON Lines (JSONL) on `stdout` and logs on `stderr`.

## Subcommands

- `manager-watch`: Persistent watcher for discovery events and D-Bus owner changes.
- `list`: One-shot query of available wireless sinks.
- `start <uuid>`: Initiates a stream session to the given sink UUID.
- `stop <stream-unit>`: Terminates the active stream unit.
- `unit-watch <stream-unit>`: Monitors systemd state transitions of the stream unit.
- `diagnose`: Comprehensive capability and dependency check.

## Building

```bash
cd network_display_bridge_src
cargo build --release
cp target/release/network_display_bridge ../network_display_bridge
```

## JSONL Output Examples

### Discovery snapshot
```json
{"type":"displaysSnapshot","displays":[{"uuid":"ab12-cd34","name":"Living Room TV","priority":100,"state":0,"protocol":"chromecast"}]}
```

### Unit state event
```json
{"type":"unitState","unit":"gnome-network-displays-stream-123.service","activeState":"active","subState":"running"}
```
