import qs
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Provides a list of wallpapers and an "apply" action that calls the existing
 * switchwall.sh script. Pretty much a limited file browsing service.
 */
Singleton {
    id: root

    property string thumbgenScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/thumbgen-venv.sh`
    property string generateThumbnailsMagickScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/generate-thumbnails-magick.sh`
    property string extractColorsScriptPath: FileUtils.trimFileProtocol(Directories.extractColorsScriptPath)
    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: {
        if (Config.ready && Config.options.wallpaperSelector.useCustomDefaultPath && Config.options.wallpaperSelector.customDefaultPath) {
            return Qt.resolvedUrl("file://" + Config.options.wallpaperSelector.customDefaultPath);
        }
        return Qt.resolvedUrl(Directories.pictures + "/Wallpapers");
    }
    property alias folderModel: folderModel // Expose for direct binding when needed
    property string searchQuery: ""
    readonly property list<string> extensions: [ // TODO: add videos
        "jpg", "jpeg", "png", "webp", "avif", "bmp", "svg", "mp4", "mkv", "webm", "avi", "mov", "m4v", "ogv"
    ]
    property list<string> wallpapers: [] // List of absolute file paths (without file://)
    readonly property bool thumbnailGenerationRunning: thumbgenProc.running
    property real thumbnailGenerationProgress: 0
    property var colorCache: ({})

    signal changed()
    signal thumbnailGenerated(directory: string)
    signal thumbnailGeneratedFile(filePath: string)

    function load () {} // For forcing initialization

    property list<string> videoExtensions: [
        "mp4", "mkv", "webm", "avi", "mov", "m4v", "ogv"
    ]
    readonly property bool videoWallpaperActive: {
        const background = Config.options && Config.options.background ? Config.options.background : null;
        if (!background) return false;
        return background.useWallpaperEngine === true || root.isVideoFile(background.wallpaperPath || "");
    }
    property bool enforcingVideoWallpaperConstraints: false

    function isVideoFile(name) {
        const value = String(name || "").toLowerCase();
        return videoExtensions.some(ext => value.endsWith("." + ext));
    }

    function enforceVideoWallpaperConstraints() {
        if (!Config.ready || !root.videoWallpaperActive || root.enforcingVideoWallpaperConstraints)
            return;

        const background = Config.options.background;
        const parallax = background.parallax;
        if (!parallax)
            return;

        root.enforcingVideoWallpaperConstraints = true;

        background.blurWhenWindowsOpen = false;
        background.zoomOutEnabled = false;
        background.zoomOutStyle = 1;
        background.windowZoomOnOverview = false;
        background.windowZoomLiveCapture = false;
        background.cheatsheetZoomOut = false;
        background.overviewZoomOut = false;
        background.workspaceBlur = false;

        parallax.vertical = false;
        parallax.autoVertical = false;
        parallax.enableWorkspace = false;
        parallax.enableSidebar = false;
        parallax.loop = false;
        parallax.invertHorizontal = false;
        parallax.invertVertical = false;
        parallax.workspaceZoom = 1.0;

        root.enforcingVideoWallpaperConstraints = false;
        Config.saveOptionsNow();
    }

    // Executions
    Process {
        id: applyProc
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return;
            if (Config.options.background.useWallpaperEngine) {
                if (Config.options.background.wallpaperEngineId) {
                    root.apply(Config.options.background.wallpaperEngineId, Appearance.m3colors.darkmode);
                }
            } else if (root.isVideoFile(Config.options.background.wallpaperPath.toLowerCase())) {
                root.apply(Config.options.background.wallpaperPath, Appearance.m3colors.darkmode);
            }
            root.enforceVideoWallpaperConstraints();
            // Pre-generate lockscreen colors if configured but missing
            if (Config.options.background.useSeparateLockscreenWallpaper) {
                const lockPath = Config.options.background.lockscreenWallpaperPath;
                const deskPath = Config.options.background.wallpaperPath;
                if (lockPath && lockPath !== "" && lockPath !== deskPath) {
                    lockscreenColorsCheckProc.exec(["test", "-f", Directories.lockscreenColorsPath]);
                }
            }
        }
    }

    Connections {
        target: Config.options ? Config.options.background : null
        enabled: Config.ready
        function onWallpaperPathChanged() {
            root.enforceVideoWallpaperConstraints();
        }
        function onUseWallpaperEngineChanged() {
            root.enforceVideoWallpaperConstraints();
        }
    }
    
    function openFallbackPicker(darkMode = Appearance.m3colors.darkmode, lockscreen = false) {
        const envBinPath = `${Directories.home}/.local/bin:${Directories.home}/.cargo/bin:/usr/local/bin:/usr/bin:/bin`;
        let args = [
            "env", "-u", "LD_LIBRARY_PATH", "-u", "PYTHONHOME", "-u", "PYTHONPATH",
            `PATH=${envBinPath}`, "bash", Directories.wallpaperSwitchScriptPath,
            "--mode", darkMode ? "dark" : "light"
        ];
        if (lockscreen) args.push("--lockscreen");
        Quickshell.execDetached(args);
    }

    function apply(path, darkMode = Appearance.m3colors.darkmode) {
        if (!path || path.length === 0) return;
        const isNumericWpeId = /^\d+$/.test(path.trim());
        if (Config.options && Config.options.background) {
            if (isNumericWpeId) {
                Config.options.background.useWallpaperEngine = true;
                Config.options.background.wallpaperEngineId = path;
            } else {
                Config.options.background.useWallpaperEngine = false;
                Config.options.background.wallpaperPath = path;
            }
        }
        Config.saveOptionsNow();
        const envBinPath = `${Directories.home}/.local/bin:${Directories.home}/.cargo/bin:/usr/local/bin:/usr/bin:/bin`;
        Quickshell.execDetached([
            "env", "-u", "LD_LIBRARY_PATH", "-u", "PYTHONHOME", "-u", "PYTHONPATH",
            `PATH=${envBinPath}`, "bash", Directories.wallpaperSwitchScriptPath,
            "--mode", darkMode ? "dark" : "light", "--image", path
        ]);
        root.changed();
    }

    function applyLockscreen(path, darkMode = Appearance.m3colors.darkmode) {
        if (!path || path.length === 0) return;
        Config.saveOptionsNow();
        const envBinPath = `${Directories.home}/.local/bin:${Directories.home}/.cargo/bin:/usr/local/bin:/usr/bin:/bin`;
        Quickshell.execDetached([
            "env", "-u", "LD_LIBRARY_PATH", "-u", "PYTHONHOME", "-u", "PYTHONPATH",
            `PATH=${envBinPath}`, "bash", Directories.wallpaperSwitchScriptPath,
            "--mode", darkMode ? "dark" : "light", "--image", path, "--lockscreen", "--noswitch"
        ]);
        Quickshell.execDetached([
            "env", "-u", "LD_LIBRARY_PATH", "-u", "PYTHONHOME", "-u", "PYTHONPATH",
            `PATH=${envBinPath}`, "bash", Directories.generateLockscreenColorsScriptPath,
            "--image", path, "--mode", darkMode ? "dark" : "light"
        ]);
        root.changed();
    }

    function applyLightModeWallpaper(path) {
        if (!path || path.length === 0) return;
        Config.saveOptionsNow();
        const envBinPath = `${Directories.home}/.local/bin:${Directories.home}/.cargo/bin:/usr/local/bin:/usr/bin:/bin`;
        Quickshell.execDetached([
            "env", "-u", "LD_LIBRARY_PATH", "-u", "PYTHONHOME", "-u", "PYTHONPATH",
            `PATH=${envBinPath}`, "bash", Directories.wallpaperSwitchScriptPath,
            "--mode", "light", "--image", path, "--lightmode"
        ]);
        root.changed();
    }

    Connections {
        target: GlobalStates
        ignoreUnknownSignals: true
        function onScreenLockedChanged() {
            console.log("[Wallpapers] onScreenLockedChanged fired, screenLocked=", GlobalStates.screenLocked);
            if (!Config.options || !Config.options.background) return;
            const useSeparate = Config.options.background.useSeparateLockscreenWallpaper;
            console.log("[Wallpapers] useSeparate=", useSeparate);
            if (!useSeparate) return;
            const lockPath = Config.options.background.lockscreenWallpaperPath;
            const deskPath = Config.options.background.wallpaperPath;
            console.log("[Wallpapers] lockPath=", lockPath, "deskPath=", deskPath);
            if (!lockPath || lockPath === "" || lockPath === deskPath) return;

            // Atomic swap: just copy pre-generated JSON, no matugen runtime cost
            if (GlobalStates.screenLocked) {
                console.log("[Wallpapers] Calling swap lock");
                Quickshell.execDetached(["bash", Directories.swapLockscreenColorsScriptPath, "lock"]);
            } else {
                console.log("[Wallpapers] Calling swap unlock");
                Quickshell.execDetached(["bash", Directories.swapLockscreenColorsScriptPath, "unlock"]);
            }
        }
    }

    Connections {
        target: Appearance.m3colors
        function onDarkmodeChanged() {
            if (!Config.options || !Config.options.background) return;
            if (!Config.options.background.useSeparateLightModeWallpaper) return;
            const lightPath = Config.options.background.lightModeWallpaperPath;
            const darkPath = Config.options.background.wallpaperPath;
            
            if (Appearance.m3colors.darkmode) {
                // Switched to dark mode — apply dark wallpaper
                if (darkPath && darkPath !== "") {
                    root.apply(darkPath, true);
                }
            } else {
                // Switched to light mode — apply light wallpaper
                if (lightPath && lightPath !== "") {
                    root.applyLightModeWallpaper(lightPath);
                }
            }
        }
    }

    function select(filePath, darkMode = Appearance.m3colors.darkmode) {
        if (!filePath || filePath.length === 0) return;
        const cleanPath = FileUtils.trimFileProtocol(filePath);
        if (Config.options?.background?.useSeparateLightModeWallpaper && !Appearance.m3colors.darkmode) {
            root.applyLightModeWallpaper(cleanPath);
        } else {
            root.apply(cleanPath, darkMode);
        }
    }

    function selectLockscreen(filePath, darkMode = Appearance.m3colors.darkmode) {
        if (!filePath || filePath.length === 0) return;
        const cleanPath = FileUtils.trimFileProtocol(filePath);
        root.applyLockscreen(cleanPath, darkMode);
    }

    function selectLightmode(filePath, darkMode = Appearance.m3colors.darkmode) {
        if (!filePath || filePath.length === 0) return;
        const cleanPath = FileUtils.trimFileProtocol(filePath);
        if (Config.options?.background?.useSeparateLightModeWallpaper && !Appearance.m3colors.darkmode) {
            root.applyLightModeWallpaper(cleanPath);
        } else {
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", darkMode ? "dark" : "light", "--image", cleanPath, "--lightmode", "--noswitch"]);
            root.changed()
        }
    }

    function randomFromCurrentFolder(darkMode = Appearance.m3colors.darkmode) {
        if (folderModel.count === 0) return;
        const randomIndex = Math.floor(Math.random() * folderModel.count);
        const filePath = folderModel.get(randomIndex, "filePath");
        print("Randomly selected wallpaper:", filePath);
        root.select(filePath, darkMode);
    }

    Process {
        id: validateDirProc
        property string nicePath: ""
        function setDirectoryIfValid(path) {
            validateDirProc.nicePath = FileUtils.trimFileProtocol(path).replace(/\/+$/, "")
            if (/^\/*$/.test(validateDirProc.nicePath)) validateDirProc.nicePath = "/";
            validateDirProc.exec([
                "bash", "-c",
                `if [ -d "${validateDirProc.nicePath}" ]; then echo dir; elif [ -f "${validateDirProc.nicePath}" ]; then echo file; else echo invalid; fi`
            ])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                    root.directory = Qt.resolvedUrl(validateDirProc.nicePath)
                const result = text.trim()
                if (result === "dir") {
                } else if (result === "file") {
                    root.directory = Qt.resolvedUrl(FileUtils.parentDirectory(validateDirProc.nicePath))
                } else {
                    // Ignore
                }
            }
        }
    }
    function setDirectory(path) {
        validateDirProc.setDirectoryIfValid(path)
    }
    function reloadCurrentDirectory() {
    const current = folderModel.folder
    const currentPath = FileUtils.trimFileProtocol(current.toString())
    const parent = FileUtils.parentDirectory(currentPath) || "/"
    folderModel.lockNextNavigation()
    folderModel.folder = Qt.resolvedUrl(parent)
    folderModel.lockNextNavigation()
    folderModel.folder = current
    }

    function navigateUp() {
        folderModel.navigateUp()
    }
    function navigateBack() {
        folderModel.navigateBack()
    }
    function navigateForward() {
        folderModel.navigateForward()
    }

    // Folder model
    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(root.defaultFolder)
        caseSensitive: false
        nameFilters: root.extensions.map(ext => `*${searchQuery.split(" ").filter(s => s.length > 0).map(s => `*${s}*`)}*.${ext}`)
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Time
        sortReversed: false
        onCountChanged: {
            root.wallpapers = []
            for (let i = 0; i < folderModel.count; i++) {
                const path = folderModel.get(i, "filePath") || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL"))
                if (path && path.length) root.wallpapers.push(path)
            }
        }
    }

    // Thumbnail generation
    function generateThumbnail(size: string, force = false) {
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) throw new Error("Invalid thumbnail size");
        thumbgenProc.directory = root.directory
        thumbgenProc.running = false
        const forceArg = force ? " --force" : ""
        thumbgenProc.command = [
            "bash", "-c",
            `${thumbgenScriptPath} --size ${size} --machine_progress -d '${StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(root.directory))}' || true; ${generateThumbnailsMagickScriptPath} --size ${size}${forceArg} -d '${StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(root.directory))}'`,
        ]
        // console.log("[Wallpapers] Updating thumbnails with command ", thumbgenProc.command.join(" "))
        root.thumbnailGenerationProgress = 0
        thumbgenProc.running = true
    }
    Process {
        id: thumbgenProc
        property string directory
        stdout: SplitParser {
            onRead: data => {
                // print("thumb gen proc:", data)
                let match = data.match(/PROGRESS (\d+)\/(\d+)/)
                if (match) {
                    const completed = parseInt(match[1])
                    const total = parseInt(match[2])
                    root.thumbnailGenerationProgress = completed / total
                }
                match = data.match(/FILE (.+)/)
                if (match) {
                    const filePath = match[1]
                    root.thumbnailGeneratedFile(filePath)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // print("[Wallpapers] Thumbnail generation completed with exit code", exitCode)
            root.thumbnailGenerated(thumbgenProc.directory)
        }
    }

    Process {
        id: readColorCacheProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    try {
                        root.colorCache = JSON.parse(text);
                    } catch (e) {
                        console.error("[Wallpapers] Failed to parse color cache:", e);
                    }
                }
            }
        }
    }

    function loadColorCache() {
        const path = Directories.colorCachePath;
        readColorCacheProc.exec(["cat", path]);
    }

    Component.onCompleted: {
        root.loadColorCache();
    }

    // Checks if lockscreen_colors.json exists; if not, generates it in background
    Process {
        id: lockscreenColorsCheckProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // File doesn't exist: generate lockscreen colors in background
                const lockPath = Config.options.background.lockscreenWallpaperPath;
                const mode = Appearance.m3colors.darkmode ? "dark" : "light";
                Quickshell.execDetached(["bash", Directories.generateLockscreenColorsScriptPath, "--image", lockPath, "--mode", mode]);
            }
        }
    }

    IpcHandler {
        target: "wallpapers"

        function apply(path: string): void {
            root.apply(path);
        }

        function applyLockscreen(path: string): void {
            root.applyLockscreen(path);
        }
    }
}
