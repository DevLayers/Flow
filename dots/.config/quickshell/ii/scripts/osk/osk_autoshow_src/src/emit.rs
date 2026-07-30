use std::io::Write;

/// Writes one event line to stdout and flushes immediately.
///
/// `println!` already takes the stdout lock, so the evdev watcher threads and the
/// Wayland thread can call this concurrently without interleaving partial lines.
pub fn emit(line: &str) {
    let mut out = std::io::stdout().lock();
    let _ = writeln!(out, "{line}");
    let _ = out.flush();
}
