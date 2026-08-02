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

## Installation

The QML side ships with the config and needs nothing done to it. Two things do not
ship and have to be put in place by hand: the **binary**, which is built rather than
tracked, and the **udev rule**, which is outside `$HOME` and needs root. Steps 3 and 4
are only for a config that predates this feature or was assembled by hand.

### 1. Build the binary

`rust` and `cargo` are the only build requirements. `libc` and `serde_json` are the
only dependencies, but cargo does fetch them, so the first build needs network.

```bash
yay -S --needed rust
cd ~/.config/quickshell/ii/scripts/appStats/app_stats_src
cargo build --release
cp target/release/app_stats ../
```

The result is ~530 KB. It must end up at
`~/.config/quickshell/ii/scripts/appStats/app_stats` and be executable — that exact
path is what `AppStats.qml` launches, and there is no fallback if it is missing.

Neither the binary, `target/` nor `Cargo.lock` belongs in the repo — they are
gitignored. Mirror the source and this file, and build on the target machine.
`setup-ii-p3drovfx.sh` lists `scripts/appStats/app_stats` in `PROTECTED_PATTERNS`, so
a config update carries the built binary across instead of deleting it. Rebuild after
any change to `app_stats_src/`; nothing rebuilds it automatically.

### 2. Install the udev rule

Without it every RAPL read fails and energy silently degrades to whole-battery drain,
which reads zero on AC. Write `/etc/udev/rules.d/99-rapl-readable.rules`:

```udev
# Expose Intel RAPL energy counters to the wheel group.
#
# energy_uj was restricted to root (mode 400) as the mitigation for
# CVE-2020-8694 (PLATYPUS), a power side-channel attack. Members of wheel can
# already read these counters via sudo, so widening to wheel grants no
# capability that group did not already have -- it only removes the need to run
# the usage-stats sampler as root.
#
# Only energy_uj is touched; name and max_energy_range_uj are already 0444.
# Matches intel-rapl:0 (package), :0:0 (core), :0:1 (uncore/iGPU), :0:2 (dram).

SUBSYSTEM=="powercap", KERNEL=="intel-rapl:*", TEST=="/sys$devpath/energy_uj", \
  RUN+="/usr/bin/chgrp wheel /sys$devpath/energy_uj", \
  RUN+="/usr/bin/chmod g+r /sys$devpath/energy_uj"
```

Apply it to the already-enumerated devices without a reboot, then check that reading
works **as your own user** — the daemon never uses `sudo`:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=powercap
stat -c '%A %G %n' /sys/class/powercap/intel-rapl:0/energy_uj   # -r--r----- wheel
cat /sys/class/powercap/intel-rapl:0/energy_uj                  # a number, no EACCES
```

You must be in `wheel` (`groups | grep wheel`); adding yourself needs a re-login. On a
machine with no `intel-rapl` at all — AMD, or a VM — skip this step and set
`energySource` to `battery`.

### 3. Hyprland keybind and layer rules

Shipped in `dots/.config/hypr/hyprland/`. On a config that already has them, `hyprctl
reload` is enough. Otherwise add to `keybinds.lua`:

```lua
hl.bind("SUPER + U", hl.dsp.global("quickshell:usageToggle"), { description = "Shell: Toggle app usage stats" })
```

and to `rules.lua`, so the overlay blurs and slides like the other panels:

```lua
hl.layer_rule({ match = { namespace = "quickshell:usage" }, blur = true})
hl.layer_rule({ match = { namespace = "quickshell:usage" }, ignore_alpha = 0.6})
hl.layer_rule({ match = { namespace = "quickshell:usage" }, animation = "slide bottom"})
```

The overlay still opens without these — it is reachable from the IPC call
`qs ipc call usage toggle` — but it renders unblurred and pops in.

### 4. Shell wiring

All of this is already in the config; it is listed so a hand-assembled tree can be
checked against it.

| File | What it adds |
| --- | --- |
| `services/AppStats.qml` | the singleton that runs the sampler and parses the day files |
| `modules/ii/usage/` | the overlay: `Usage`, `UsageContent`, `UsageAppRow`, `UsageBarChart`, `UsageFormat.js` |
| `modules/common/Config.qml` | the `appStats` option group |
| `modules/common/Directories.qml` | `Directories.appStats`, the state dir |
| `GlobalStates.qml` | `usageOpen` |
| `panelFamilies/*.qml` | a `PanelLoader` for `Usage`, in both families |
| `shell.qml` | touches `AppStats.stateDir` on startup |

That last line is not optional. The singleton is lazy, so without it nothing is
collected until the overlay is opened for the first time.

### 5. Restart and verify

```bash
qs kill; qs &                                   # or: touch ~/.config/quickshell/ii/shell.qml
pgrep -af app_stats                             # one process, with the flags from Config
ls ~/.local/state/quickshell/user/app_stats/    # YYYY-MM-DD.json within a minute
```

Then press **Super + U**. An empty first minute is expected: the day file is only
rewritten every `flushIntervalMs`.

### Configuration

`Config.options.appStats` in `~/.config/illogical-impulse/config.json`. Everything
except the last two is passed to the daemon on its command line and is read once at
startup, so changing them restarts it.

| Key | Default | Effect |
| --- | --- | --- |
| `enable` | `true` | run the sampler at all |
| `sampleIntervalMs` | `10000` | counter poll period |
| `flushIntervalMs` | `60000` | day-file write period |
| `retentionDays` | `30` | day files older than this are deleted |
| `energySource` | `"auto"` | `auto`, `rapl`, `battery` or `none` |
| `idleTimeoutSec` | `300` | seconds without input before foreground time stops; `0` disables the idle monitor |
| `trackHeadless` | `true` | record processes that own no window |
| `showHeadless` | `false` | show those processes in the list (toggleable in the overlay) |
| `overlayEnabled` | `true` | load the overlay panel |

Turning `enable` off stops collection but keeps the history; deleting the state
directory is what discards it.

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

None of these are checked at startup; each one missing costs a category of data
rather than stopping the daemon.

- **The udev rule** from installation step 2. Without it every RAPL read fails and the
  daemon falls back to whole-battery drain split by a fixed ratio — much cruder, and
  zero while on AC. The daemon never uses `sudo`.
- A **Hyprland** session: it reads `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/`.
  On anything else there are no window events, so every process is headless and
  foreground time is always zero.
- The **`xe`** or **`i915`** driver for GPU accounting. Without per-client
  `drm-cycles-*` in fdinfo, GPU shares are simply zero and the uncore energy all
  lands in `__system`.
- **Write access to `$XDG_STATE_HOME`** for the day files. The directory is created if
  it does not exist.

## Cost

Measured on this machine at the default 10 s interval, ~450 processes, Brave and
Discord running: **6.8 ms of CPU per sample — 0.07 % of one core**, 3.5 MB RSS.

Most of that is the `/proc` sweep. The GPU scan is kept cheap by remembering which
fds of which processes are DRM fds: a full sweep opens every fd of every process,
while the scans in between reopen only the handful that matter. Removing that cache
roughly doubles the cost.
