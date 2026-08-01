# app_stats

Per-app usage and energy sampler: foreground/background screen time, watt-hours,
CPU and GPU time, memory, launches and sessions — the data behind the usage overlay.

**Binary:** `~/.config/quickshell/ii/scripts/appStats/app_stats`
**Source:** `~/.config/quickshell/ii/scripts/appStats/app_stats_src/`

## Why a helper is needed

Nothing the shell can reach in QML can answer "which app used that battery". The
numbers come from four places at once, three of which need a tight polling loop that
would stall the UI thread if it ran in QML:

- **Hyprland's event socket** for window transitions, so a workspace switch is
  recorded at the instant it happens rather than rounded to the next sample.
- **`/proc/*/stat`** for CPU and RSS across ~450 processes, folded onto apps by
  walking the parent chain — a browser's forty helper processes report as one app.
- **`/proc/*/fdinfo/*`** for per-client GPU engine cycles from the `xe` driver.
- **`/sys/class/powercap/intel-rapl:0*`** for real energy counters.

The daemon knows only pids, window classes and counters. It resolves no desktop
entries, icons or themes — that happens in QML, which already has `AppSearch`. That
split is what keeps it at ~3.5 MB RSS.

## Building

```bash
cd ~/.config/quickshell/ii/scripts/appStats/app_stats_src
cargo build --release
cp target/release/app_stats ../
```

Neither the binary, `target/` nor `Cargo.lock` belongs in the repo — mirror the
source and this file, and build on the target machine.

## Running it by hand

It is a normal program: run it in a terminal and watch the NDJSON.

```bash
./app_stats --state-dir /tmp/stats --interval-ms 3000
```

| Flag | Default | Effect |
| --- | --- | --- |
| `--interval-ms` | `10000` | counter poll period (minimum 1000) |
| `--flush-ms` | `60000` | how often the day file is rewritten |
| `--retention-days` | `30` | day files older than this are deleted |
| `--state-dir` | `$XDG_STATE_HOME/quickshell/user/app_stats` | where day files go |
| `--energy` | `auto` | `rapl`, `battery`, `auto` or `off` |
| `--gpu-full-every` | `30` | intervals between full GPU rescans (a new window forces one) |
| `--no-headless` | — | skip processes that own no window |
| `--quiet` | — | write day files, print nothing |

## Protocol

One JSON object per line, in both directions.

**stdin**

| Line | Meaning |
| --- | --- |
| `{"t":"state","locked":true,"idle":false,"dpms":"off"}` | screen state changed; foreground time stops accruing while any of these hold |
| `{"t":"flush"}` | write the day file now |
| `{"t":"quit"}` | flush and exit (`SIGTERM` does the same) |

**stdout**

| Line | Meaning |
| --- | --- |
| `{"t":"ready",…}` | startup: energy source in use, interval, state dir |
| `{"t":"sample",…}` | one interval's deltas per app, plus the unattributed remainder |
| `{"t":"flush","file":…}` | a day file was written |

## Storage

One sparse file per local day, `YYYY-MM-DD.json`, so today's chart never has to parse
a month of history and retention is an unlink. Each app maps hours to a fixed tuple:

| idx | field | unit | | idx | field | unit |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | `fg` | s | | 6 | `ramPeak` | MiB |
| 1 | `bg` | s | | 7 | `mJfg` | mJ |
| 2 | `focus` | s | | 8 | `mJbg` | mJ |
| 3 | `cpu` | s | | 9 | `launches` | count |
| 4 | `gpu` | s | | 10 | `sessions` | count |
| 5 | `ramAvg` | MiB | | | | |

`focus` is a subset of `fg`: on a tiling WM every mapped window on the active
workspace is "foreground", which inflates screen time, so focused time is recorded
separately and the UI can switch which one it reports without recollecting anything.

Written directly rather than through `JsonAdapter`, so the numeric tuples cannot be
silently coerced to another type.

## Energy attribution

RAPL measures the whole package and cannot see processes, so per-app energy is a
model, not a measurement:

```
E(app) = ΔE_core × cpu_share + ΔE_uncore × gpu_share + ΔE_dram × rss_share
```

Whatever is left over — idle draw, kernel threads, display backlight, radios — goes
into an explicit `__system` bucket instead of being normalised away. On this machine
that residual is **50–60 %** at light load, which is the honest measure of how much
weight the per-app numbers can bear.

## Requirements

- **`/etc/udev/rules.d/99-rapl-readable.rules`**, which makes `energy_uj` readable by
  the `wheel` group. Without it every RAPL read fails and the daemon falls back to
  whole-battery drain split by a fixed ratio — much cruder, and zero while on AC.
  The daemon never uses `sudo`.
- A **Hyprland** session: it reads `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/`.
- The **`xe`** or **`i915`** driver for GPU accounting. Without per-client
  `drm-cycles-*` in fdinfo, GPU shares are simply zero and the uncore energy all
  lands in `__system`.

## Cost

Measured on this machine at the default 10 s interval, ~450 processes, Brave and
Discord running: **6.8 ms of CPU per sample — 0.07 % of one core**, 3.5 MB RSS.

Most of that is the `/proc` sweep. The GPU scan is kept cheap by remembering which
fds of which processes are DRM fds: a full sweep opens every fd of every process,
while the scans in between reopen only the handful that matter. Removing that cache
roughly doubles the cost.
