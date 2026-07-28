pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.modules.common

/**
 * Searches YouTube for music videos via yt-dlp and plays them as a background
 * layer via mpvpaper (wlr_layer_shell). The video appears behind the media mode
 * overlay, creating a "music video background" effect.
 *
 * Lifecycle:
 *   1. Track changes → search yt-dlp (async via Process)
 *   2. URL found → launch mpvpaper at Background layer
 *   3. Track changes / media mode closes → kill mpvpaper
 */
Singleton {
    id: root

    // ── Public API ──────────────────────────────────────────────────────────

    /// Whether the music video background is globally enabled.
    readonly property bool enabled: Config.options.background.mediaMode.musicVideo.enable

    /// True while a video is currently playing (mpvpaper process is running).
    readonly property bool videoPlaying: mpvpaperProc.running

    /// The last video URL that was played (for debugging).
    readonly property string currentVideoUrl: _currentUrl

    /// The search query used for the last successful search.
    readonly property string lastSearchQuery: _lastQuery

    /// True if the last search failed (shows fallback UI).
    readonly property bool searchFailed: _searchFailed


    // ── Internal state ──────────────────────────────────────────────────────

    property string _currentUrl: ""
    property string _lastQuery: ""
    property string _cachedUrl: ""       // persists across enable/disable cycles
    property bool _searchFailed: false
    property int _savedBlurSize: 0       // saved before disabling compositor blur
    property int _pendingSeek: 0         // seek target in seconds (IPC fallback)
    property string _pendingArtist: ""
    property string _pendingTitle: ""
    property bool _wasPlayingBefore: false
    property string _searchingForTrack: ""  // guards stale yt-dlp results after track skip
    property bool _syncInitial: true        // true → first sync uses longer delay for YouTube URL resolution

    // ── Track change detection ──────────────────────────────────────────────

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string currentTrackId: {
        const artist = activePlayer?.trackArtist ?? "";
        const title = activePlayer?.trackTitle ?? "";
        return artist + "|||" + title;
    }

    onCurrentTrackIdChanged: {
        if (!root.enabled) return;
        if (currentTrackId === "" || currentTrackId === "|||") return;
        // Avoid re-searching the same track
        if (currentTrackId === root._lastQuery) return;
        root.searchAndPlay();
    }

    // ── Reliable track change detection ───────────────────────────────────────
    // activeTrack is a property var that gets reassigned on every track change,
    // so activeTrackChanged fires reliably even when the QML binding chain
    // through optional-chaining fails to detect the update.

    Connections {
        target: MprisController
        function onActiveTrackChanged() {
            if (!root.enabled) return;
            const track = MprisController.activeTrack;
            if (!track) return;
            const newId = (track.artist || "") + "|||" + (track.title || "");
            if (newId === "" || newId === "|||") return;
            if (newId === root._lastQuery) return;
            root.searchAndPlay();
        }
    }

    // ── Media mode state watcher ────────────────────────────────────────────

    Connections {
        target: GlobalStates
        function onMediaModeActiveChanged() {
            if (!GlobalStates.mediaModeActive) {
                // Media mode closed entirely — kill video
                root.stopVideo();
            } else if (root.enabled && root.currentTrackId !== ""
                       && root.currentTrackId !== root._lastQuery
                       && !root.videoPlaying) {
                // Media mode opened with a new track — search
                root.searchAndPlay();
            }
        }
    }

    // ── Playback sync: pause / resume video with music ───────────────────────

    readonly property var _activePlayerRef: MprisController.activePlayer
    readonly property bool _playerIsPlaying: root._activePlayerRef?.isPlaying ?? true

    on_PlayerIsPlayingChanged: {
        if (!root.videoPlaying || !root._ipcSocket) return;
        if (root._playerIsPlaying) {
            root._resumeMpv();
        } else {
            root._pauseMpv();
        }
    }


    // ── Core: search + play ─────────────────────────────────────────────────

    function searchAndPlay() {
        if (!root.enabled) return;
        if (!GlobalStates.mediaModeActive) return;

        const artist = root.activePlayer?.trackArtist ?? "";
        const title = root.activePlayer?.trackTitle ?? "";
        if (!title) return;

        // Build search query
        const suffix = Config.options.background.mediaMode.musicVideo.searchSuffix ?? "official music video";
        const query = artist ? (artist + " - " + title + " " + suffix) : (title + " " + suffix);

        root._lastQuery = root.currentTrackId;
        root._pendingArtist = artist;
        root._pendingTitle = title;
        root._searchFailed = false;

        // Kill any currently playing video + track stale guard
        root.stopVideo();
        root._searchingForTrack = root.currentTrackId;

        // Search yt-dlp asynchronously — use --get-id for speed (no URL resolution)
        // mpvpaper will handle format selection via --ytdl-format
        searchProc.command = ["bash", "-c",
            "yt-dlp ytsearch1:" + _shellEscape(query) +
            " --get-id --no-playlist --socket-timeout 5" +
            " --no-warnings 2>/dev/null"];
        searchProc.running = true;
    }

    function _shellEscape(s) {
        // Escape single quotes for bash -c
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function stopVideo() {
        if (mpvpaperProc.running) {
            mpvpaperProc.running = false;
        }
        // Stop sync timer immediately
        syncTimer.stop();
        // Force-kill any lingering mpvpaper processes to prevent stale videos
        // from blocking new ones on the same monitor.
        Quickshell.execDetached(["pkill", "-f", "mpvpaper"]);
        root._currentUrl = "";
        root._searchingForTrack = "";
        // Clean up IPC socket
        if (root._ipcSocket) {
            Quickshell.execDetached(["rm", "-f", root._ipcSocket]);
            root._ipcSocket = "";
        }
        // Restore compositor blur that was disabled when video started
        _restoreCompositorBlur();
    }

    // Used when user toggles the feature ON mid-session
    function tryPlayCurrent() {
        if (!root.enabled) return;
        if (!GlobalStates.mediaModeActive) return;
        if (root.videoPlaying) return;
        if (!root.currentTrackId || root.currentTrackId === "|||") return;

        // If we already have a cached URL for this track, reuse it
        if (root.currentTrackId === root._lastQuery && root._cachedUrl !== "") {
            root._searchingForTrack = root.currentTrackId;
            root._launchMpvpaper(root._cachedUrl);
            return;
        }

        root.searchAndPlay();
    }


    // ── Process: yt-dlp search ──────────────────────────────────────────────

    Process {
        id: searchProc
        running: false

        stdout: SplitParser {
            onRead: function(data) {
                // Guard: ignore stale results from a previous track's search
                if (root._searchingForTrack !== root.currentTrackId) return;
                const videoId = String(data).trim();
                // Accept any non-empty video ID (11 chars for standard YT IDs)
                if (videoId.length >= 10) {
                    const youtubeUrl = "https://www.youtube.com/watch?v=" + videoId;
                    root._currentUrl = youtubeUrl;
                    root._cachedUrl = youtubeUrl;
                    root._launchMpvpaper(youtubeUrl);
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || root._currentUrl === "") {
                root._searchFailed = true;
                console.warn("[MusicVideo] yt-dlp search failed for:", root._lastQuery);
            }
        }
    }


    // ── Process: mpvpaper ───────────────────────────────────────────────────

    function _launchMpvpaper(url) {
        // Guard: user may have toggled the feature off while yt-dlp was searching
        if (!root.enabled) return;
        // Guard: track may have changed while yt-dlp was searching
        if (root._searchingForTrack !== root.currentTrackId) return;

        const monitorName = _getActiveMonitorName();
        if (!monitorName) {
            console.warn("[MusicVideo] No active monitor found, cannot launch mpvpaper");
            root._searchFailed = true;
            return;
        }

        // Get current music position for sync (microseconds → seconds)
        const posUs = MprisController.activePlayer?.position ?? 0;
        const startSec = Math.floor(posUs / 1000000);

        // Unique IPC socket for pause/resume/seek control
        const socketPath = "/tmp/ii-musicvideo.sock";

        // Build mpvpaper command — use --ytdl-format for quality (resolved by mpv's yt-dlp)
        const maxRes = Config.options.background.mediaMode.musicVideo.maxResolution ?? 1080;
        const ytdlFormat = "bestvideo[height<=" + maxRes + "]+bestaudio/best[height<=" + maxRes + "]";
        const mpvOpts = [
            "--aid=no",
            "--no-border",
            "--loop=inf",
            "--no-terminal",
            "--start=" + startSec,
            "--input-ipc-server=" + socketPath,
            "--ytdl-format=" + ytdlFormat
        ];

        mpvpaperProc.command = [
            "mpvpaper",
            "-l", "background",
            monitorName,
            url,
            "-o", mpvOpts.join(" ")
        ];

        mpvpaperProc.running = true;
        root._ipcSocket = socketPath;

        // Start sync timer: first fire at 5s (waits for mpv's yt-dlp YouTube URL resolution),
        // subsequent fires every 3s (handles user seeks and drift).
        root._syncInitial = true;
        syncTimer.interval = 5000;
        syncTimer.restart();

        // Apply pause state immediately (in case music was paused when search finished)
        if (!(MprisController.activePlayer?.isPlaying ?? true)) {
            _pauseMpv();
        }

        // Disable Hyprland compositor blur
        _disableCompositorBlur();
    }

    // ── Playback sync helpers ─────────────────────────────────────────────────

    property string _ipcSocket: ""

    function _sendMpvCommand(jsonCmd) {
        if (!root._ipcSocket) return;
        const escaped = jsonCmd.replace(/'/g, "'\\''");
        Quickshell.execDetached(["bash", "-c",
            "echo '" + escaped + "' | socat - UNIX-CONNECT:" + root._ipcSocket + " 2>/dev/null"]);
    }

    function _pauseMpv() {
        _sendMpvCommand('{"command":["set_property","pause",true]}');
    }

    function _resumeMpv() {
        _sendMpvCommand('{"command":["set_property","pause",false]}');
    }

    // ── Delayed IPC seek + periodic sync ────────────────────────────────────
    // First trigger waits 5s for mpv's internal yt-dlp to resolve YouTube URLs.
    // Subsequent triggers at 3s intervals handle user seeks and drift correction.

    Timer {
        id: syncTimer
        interval: 5000  // long initial delay to wait for YouTube URL resolution
        repeat: true
        running: false
        onTriggered: {
            // After first fire, switch to shorter periodic interval
            if (root._syncInitial) {
                root._syncInitial = false;
                syncTimer.interval = 3000;
            }
            if (!root._ipcSocket || !root.videoPlaying) {
                syncTimer.stop();
                return;
            }
            const posUs = MprisController.activePlayer?.position ?? 0;
            const currentSec = Math.floor(posUs / 1000000);
            if (currentSec > 0) {
                root._sendMpvCommand('{"command":["seek","' + currentSec + '","absolute"]}');
            }
        }
    }

    function _disableCompositorBlur() {
        // Set blur size to 0 to effectively disable compositor blur.
        // Using decoration:blur:enabled=0 doesn't affect layer shell blur rules.
        // We save the current size so we can restore it when video stops.
        root._savedBlurSize = Config.options.appearance.blurSize ?? 8;
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ decoration = { blur = { size = 0 } } })"]);
    }

    function _restoreCompositorBlur() {
        if (root._savedBlurSize > 0) {
            Quickshell.execDetached(["hyprctl", "eval",
                "hl.config({ decoration = { blur = { size = " + root._savedBlurSize + " } } })"]);
            root._savedBlurSize = 0;
        }
    }

    function _getActiveMonitorName() {
        // Get the focused monitor name via hyprctl
        // This is called synchronously from QML, so we need a pure JS approach
        try {
            const focusedMonitor = Hyprland.focusedMonitor;
            if (focusedMonitor && focusedMonitor.name) {
                return focusedMonitor.name;
            }
        } catch (e) {}
        // Fallback: use first screen
        try {
            if (Quickshell.screens && Quickshell.screens.length > 0) {
                return Quickshell.screens[0].name;
            }
        } catch (e) {}
        return "";
    }

    Process {
        id: mpvpaperProc
        running: false

        onExited: function(exitCode, exitStatus) {
            root._currentUrl = "";
            if (exitCode !== 0 && !root._searchFailed) {
                console.warn("[MusicVideo] mpvpaper exited with code:", exitCode);
                root._searchFailed = true;
            }
        }
    }


    // ── Cleanup ─────────────────────────────────────────────────────────────

    Component.onDestruction: {
        if (mpvpaperProc.running) {
            // Force-kill mpvpaper since Process.stop() might not work on exit
            Quickshell.execDetached(["pkill", "-f", "mpvpaper.*" + (root._currentUrl ? root._currentUrl.substring(0, 30) : "")]);
        }
    }
}
