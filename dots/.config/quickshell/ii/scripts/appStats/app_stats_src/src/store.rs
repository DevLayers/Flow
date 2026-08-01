//! On-disk history: one sparse file per local day.
//!
//! A single 30-day file would have to be parsed in full just to draw today's chart.
//! One file per day keeps today's read small, makes yesterday immutable, and turns
//! retention into an unlink.
//!
//! The files are written here rather than through JsonAdapter on the QML side, so
//! the numeric tuples cannot be silently coerced to another type.

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

/// Bumped only when the tuple layout changes; readers must reject what they
/// cannot interpret rather than misread it.
const SCHEMA: u64 = 1;

/// Fields are stored internally at higher resolution than they are written, so a
/// day's worth of 10 s samples cannot accumulate rounding drift.
#[derive(Default, Clone)]
pub struct Bucket {
    pub fg_ms: u64,
    pub bg_ms: u64,
    pub focus_ms: u64,
    pub cpu_ms: u64,
    pub gpu_ms: u64,
    ram_sum_mib: u64,
    ram_n: u64,
    ram_peak_mib: u64,
    /// Energy in microjoules; written out as integer millijoules.
    pub uj_fg: u64,
    pub uj_bg: u64,
    pub launches: u64,
    pub sessions: u64,
}

impl Bucket {
    pub fn observe_ram(&mut self, mib: u64) {
        self.ram_sum_mib += mib;
        self.ram_n += 1;
        self.ram_peak_mib = self.ram_peak_mib.max(mib);
    }

    fn ram_avg(&self) -> u64 {
        if self.ram_n == 0 {
            0
        } else {
            self.ram_sum_mib / self.ram_n
        }
    }

    fn to_tuple(&self) -> Vec<u64> {
        vec![
            (self.fg_ms + 500) / 1000,
            (self.bg_ms + 500) / 1000,
            (self.focus_ms + 500) / 1000,
            (self.cpu_ms + 500) / 1000,
            (self.gpu_ms + 500) / 1000,
            self.ram_avg(),
            self.ram_peak_mib,
            self.uj_fg / 1000,
            self.uj_bg / 1000,
            self.launches,
            self.sessions,
        ]
    }

    /// Reload after a restart. Sub-second and sub-millijoule remainders are lost,
    /// and the RAM mean collapses to a single sample — the alternative is losing
    /// the whole morning whenever the shell reloads.
    fn from_tuple(t: &[u64]) -> Bucket {
        let g = |i: usize| t.get(i).copied().unwrap_or(0);
        Bucket {
            fg_ms: g(0) * 1000,
            bg_ms: g(1) * 1000,
            focus_ms: g(2) * 1000,
            cpu_ms: g(3) * 1000,
            gpu_ms: g(4) * 1000,
            ram_sum_mib: g(5),
            ram_n: if g(5) > 0 { 1 } else { 0 },
            ram_peak_mib: g(6),
            uj_fg: g(7) * 1000,
            uj_bg: g(8) * 1000,
            launches: g(9),
            sessions: g(10),
        }
    }
}

pub struct AppRec {
    pub exe: String,
    pub headless: bool,
    pub hours: BTreeMap<u32, Bucket>,
}

pub struct Store {
    dir: PathBuf,
    retention_days: i64,
    date: String,
    gmtoff: i64,
    apps: BTreeMap<String, AppRec>,
    dirty: bool,
}

/// Local calendar date, hour of day, and UTC offset for an epoch instant.
pub fn local(epoch_secs: i64) -> (String, u32, i64) {
    let t = epoch_secs as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe { libc::localtime_r(&t, &mut tm) };
    let date = format!(
        "{:04}-{:02}-{:02}",
        tm.tm_year + 1900,
        tm.tm_mon + 1,
        tm.tm_mday
    );
    (date, tm.tm_hour as u32, tm.tm_gmtoff as i64)
}

pub fn now_ms() -> i64 {
    let mut ts: libc::timespec = unsafe { std::mem::zeroed() };
    unsafe { libc::clock_gettime(libc::CLOCK_REALTIME, &mut ts) };
    ts.tv_sec as i64 * 1000 + ts.tv_nsec as i64 / 1_000_000
}

fn offset_string(gmtoff: i64) -> String {
    let sign = if gmtoff < 0 { '-' } else { '+' };
    let a = gmtoff.abs();
    format!("{}{:02}:{:02}", sign, a / 3600, (a % 3600) / 60)
}

impl Store {
    pub fn new(dir: PathBuf, retention_days: i64) -> Store {
        let _ = fs::create_dir_all(&dir);
        let (date, _, gmtoff) = local(now_ms() / 1000);
        let mut store = Store {
            dir,
            retention_days,
            date,
            gmtoff,
            apps: BTreeMap::new(),
            dirty: false,
        };
        store.load();
        store.prune();
        store
    }

    fn path_for(&self, date: &str) -> PathBuf {
        self.dir.join(format!("{date}.json"))
    }

    /// Pick up where a previous run left off, if it ran today.
    fn load(&mut self) {
        let Ok(raw) = fs::read_to_string(self.path_for(&self.date)) else {
            return;
        };
        let Ok(json) = serde_json::from_str::<serde_json::Value>(&raw) else {
            return;
        };
        if json.get("v").and_then(|v| v.as_u64()) != Some(SCHEMA) {
            return;
        }
        let Some(apps) = json.get("apps").and_then(|a| a.as_object()) else {
            return;
        };

        for (key, rec) in apps {
            let mut hours = BTreeMap::new();
            if let Some(h) = rec.get("h").and_then(|h| h.as_object()) {
                for (hour, tuple) in h {
                    let Ok(hour) = hour.parse::<u32>() else { continue };
                    let Some(arr) = tuple.as_array() else { continue };
                    let vals: Vec<u64> = arr.iter().map(|v| v.as_u64().unwrap_or(0)).collect();
                    hours.insert(hour, Bucket::from_tuple(&vals));
                }
            }
            self.apps.insert(
                key.clone(),
                AppRec {
                    exe: rec
                        .get("exe")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    headless: rec
                        .get("headless")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false),
                    hours,
                },
            );
        }
    }

    /// Bucket for `epoch_ms`, rolling the day file over first if the date changed.
    pub fn bucket(&mut self, epoch_ms: i64, key: &str, exe: &str, headless: bool) -> &mut Bucket {
        let (date, hour, gmtoff) = local(epoch_ms / 1000);
        if date != self.date {
            self.flush();
            self.apps.clear();
            self.date = date;
            self.gmtoff = gmtoff;
            self.prune();
        }
        self.dirty = true;

        let rec = self.apps.entry(key.to_string()).or_insert_with(|| AppRec {
            exe: exe.to_string(),
            headless,
            hours: BTreeMap::new(),
        });
        // A name learned later (the proc sweep runs after the window appears) is
        // better than the placeholder recorded at first sight.
        if rec.exe.is_empty() && !exe.is_empty() {
            rec.exe = exe.to_string();
        }
        rec.hours.entry(hour).or_default()
    }

    /// End of the local hour containing `epoch_ms`, so a span can be split across
    /// an hour boundary instead of landing wholly in the wrong bucket.
    pub fn hour_end_ms(&self, epoch_ms: i64) -> i64 {
        let (_, _, gmtoff) = local(epoch_ms / 1000);
        let local_secs = epoch_ms / 1000 + gmtoff;
        ((local_secs / 3600) + 1) * 3600 * 1000 - gmtoff * 1000
    }

    pub fn flush(&mut self) -> Option<PathBuf> {
        if !self.dirty {
            return None;
        }

        let apps: serde_json::Map<String, serde_json::Value> = self
            .apps
            .iter()
            .map(|(key, rec)| {
                let hours: serde_json::Map<String, serde_json::Value> = rec
                    .hours
                    .iter()
                    .map(|(h, b)| (h.to_string(), serde_json::json!(b.to_tuple())))
                    .collect();
                (
                    key.clone(),
                    serde_json::json!({
                        "exe": rec.exe,
                        "headless": rec.headless,
                        "h": hours,
                    }),
                )
            })
            .collect();

        let doc = serde_json::json!({
            "v": SCHEMA,
            "date": self.date,
            "tz": offset_string(self.gmtoff),
            "apps": apps,
        });

        // Write-then-rename: a reader must never see a half-written day.
        let path = self.path_for(&self.date);
        let tmp = path.with_extension("json.tmp");
        if fs::write(&tmp, doc.to_string()).is_err() {
            return None;
        }
        if fs::rename(&tmp, &path).is_err() {
            let _ = fs::remove_file(&tmp);
            return None;
        }
        self.dirty = false;
        Some(path)
    }

    fn prune(&mut self) {
        if self.retention_days <= 0 {
            return;
        }
        let cutoff = local(now_ms() / 1000 - self.retention_days * 86400).0;
        let Ok(dir) = fs::read_dir(&self.dir) else {
            return;
        };
        for entry in dir.flatten() {
            let path = entry.path();
            let Some(stem) = path.file_stem().and_then(|s| s.to_str()) else {
                continue;
            };
            if path.extension().and_then(|e| e.to_str()) != Some("json") {
                continue;
            }
            // ISO dates sort lexicographically, so a string compare is a date compare.
            if stem.len() == 10 && stem < cutoff.as_str() {
                let _ = fs::remove_file(&path);
            }
        }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }
}
