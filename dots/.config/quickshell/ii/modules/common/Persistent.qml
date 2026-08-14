pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property alias states: persistentStatesJsonAdapter
    property string fileDir: Directories.state
    property string fileName: "states.json"
    property string filePath: `${root.fileDir}/${root.fileName}`

    property bool ready: false
    property string previousHyprlandInstanceSignature: ""
    property bool isNewHyprlandInstance: previousHyprlandInstanceSignature !== states.hyprlandInstanceSignature
    // See Config.qml for the rationale on these guards. Same pattern: avoid
    // clobbering the on-disk states.json with QML defaults during transient
    // file inaccessibility, and write atomically so a kill mid-save cannot
    // corrupt the file.
    property bool blockWrites: false
    property real initTimestamp: Date.now()
    property int missingFileGracePeriod: 5000
    property int missingFileRetryInterval: 1500
    // Same write guard as Config.qml — prevents hot-reload race condition.
    // Increased from 3000 to 5000 to match Config.qml.
    property int writeGuardDelay: 5000

    onReadyChanged: {
        root.previousHyprlandInstanceSignature = root.states.hyprlandInstanceSignature;
        root.states.hyprlandInstanceSignature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "";
    }

    Timer {
        id: fileReloadTimer
        interval: 100
        repeat: false
        onTriggered: {
            persistentStatesFileView.reload();
        }
    }

    Timer {
        id: fileWriteTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.blockWrites) {
                return;
            }
            if (!root.ready) {
                fileWriteTimer.restart();
                return;
            }
            // Extra guard: see Config.qml for rationale.
            const elapsed = Date.now() - root.initTimestamp;
            if (elapsed < root.writeGuardDelay) {
                fileWriteTimer.restart();
                return;
            }
            persistentStatesFileView.writeAdapter();
        }
    }

    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: {
            persistentStatesFileView.reload();
        }
    }

    Component.onDestruction: {
        root.blockWrites = true;
    }

    FileView {
        id: persistentStatesFileView
        path: root.filePath

        watchChanges: true
        atomicWrites: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: { if (root.ready && !root.blockWrites) fileWriteTimer.restart(); }
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load persistent states file:", error);
            if (error != FileViewError.FileNotFound) {
                return;
            }
            const elapsed = Date.now() - root.initTimestamp;
            if (elapsed > root.missingFileGracePeriod && !root.ready) {
                fileWriteTimer.restart();
                root.ready = true;
            } else {
                missingFileRetryTimer.restart();
            }
        }

        Component.onDestruction: {
            persistentStatesFileView.blockWrites = true;
        }

        adapter: JsonAdapter {
            id: persistentStatesJsonAdapter

            property string hyprlandInstanceSignature: ""

            property JsonObject ai: JsonObject {
                property string provider: "google" // AI providers such as google, open router, mistral
                property string model: "gemini-2.5-flash" // The model of the ai such as 2.5-flash
                property real temperature: 0.5
            }

            property JsonObject background: JsonObject {
                property bool widgetsMigrated: false
                property bool lockBehaviorMigrated: false
                property JsonObject mediaMode: JsonObject {
                    property real userScrollOffset: 0
                }
            }

            property JsonObject cheatsheet: JsonObject {
                property int tabIndex: 0
                property list<string> sectionOrder: []
            }

            property JsonObject clipboard: JsonObject {
                property list<string> pinnedEntries: []
            }

            property JsonObject sidebar: JsonObject {
                property JsonObject policies: JsonObject {
                    property int tab: 0
                        property JsonObject phone: JsonObject {
                            property string activeDeviceId: ""
                            property list<string> recentDeviceIds: []
                            property string cachedNotificationsJson: ""
                            property JsonObject scrcpy: JsonObject {
                                property list<string> recentPackages: []
                            }
                        }
                }
                property JsonObject bottomGroup: JsonObject {
                    property bool collapsed: false
                    property int tab: 0
                    property int todoTab: 0
                    property int timerTab: 0
                }
            }

            property JsonObject booru: JsonObject {
                property bool allowNsfw: false
                property string provider: "yandere"
            }

            property JsonObject hyprland: JsonObject {
                property string layout: "dwindle"
            }

            property JsonObject idle: JsonObject {
                property bool inhibit: false
                property real expiresAt: 0 // Epoch ms; 0 means indefinite. Must be real, not int
                property real durationMinutes: 0 // Preset the timed session started from, 0 if none
                property string sessionId: ""
            }

            property JsonObject keyboardBacklight: JsonObject {
                property bool idleOffActive: false // Whether the idle monitor is the reason it's off
                property int savedLevel: 0 // Level to return to once input resumes
            }

            property JsonObject nightLight: JsonObject {
                property bool hasManual: false // Whether a manual toggle is currently overriding automatic mode
                property bool manualActive: false
                property real manualSetAt: 0 // Epoch ms, used to tell whether the override has expired
                property int gamma: 100
                property string gammaByMonitorJson: "{}"
                property string sessionId: ""
            }

            property JsonObject overlay: JsonObject {
                property list<string> open: ["crosshair", "recorder", "media", "volumeMixer", "resources"]
                property JsonObject crosshair: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 827
                    property real y: 441
                    property real width: 250
                    property real height: 100
                }
                property JsonObject media: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 827
                    property real y: 441
                    property real width: 250
                    property real height: 100
                }
                property JsonObject floatingImage: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1650
                    property real y: 390
                    property real width: 0
                    property real height: 0
                }
                property JsonObject fpsLimiter: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1570
                    property real y: 615
                    property real width: 280
                    property real height: 80
                }
                property JsonObject recorder: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 80
                    property real width: 350
                    property real height: 130
                }
                property JsonObject resources: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 1500
                    property real y: 770
                    property real width: 350
                    property real height: 200
                    property int tabIndex: 0
                }
                property JsonObject volumeMixer: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 280
                    property real width: 350
                    property real height: 600
                    property int tabIndex: 0
                }
                property JsonObject notes: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 1400
                    property real y: 42
                    property real width: 460
                    property real height: 330
                    property int tabIndex: 0
                }
                property JsonObject discordVoice: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 600
                    property real width: 344
                    property real height: 200
                }
            }

            property JsonObject phoneCamera: JsonObject {
                property string lastMode: "wifi"   // "wifi" | "usb"
                property string lastIp: ""
                property int lastPort: 4747
            }

            property JsonObject phoneMic: JsonObject {
                property string originalDefaultSink: ""
                property string lastBackend: ""     // "scrcpy" | "droidcam"
                property string lastMode: "wifi"
                property string lastIp: ""
                property int lastPort: 4748
            }

            property JsonObject screenRecord: JsonObject {
                property bool active: false
                property int seconds: 0
                property bool loading: false
                property bool paused: false
            }

            property JsonObject settings: JsonObject {
                property list<string> collapsedGroups: []
                property JsonObject fonts: JsonObject {
                    property string main: "Google Sans Flex"
                    property string numbers: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string iconNerd: "JetBrainsMono Nerd Font"
                    property string monospace: "JetBrainsMono Nerd Font"
                    property string reading: "Readex Pro"
                    property string expressive: "Space Grotesk"
                    property bool roundnessFull: false
                }
            }

            property JsonObject timer: JsonObject {
                property JsonObject pomodoro: JsonObject {
                    property bool running: false
                    property int start: 0
                    property bool isBreak: false
                    property int cycle: 0
                }
                property JsonObject stopwatch: JsonObject {
                    property bool running: false
                    property int start: 0
                    property list<var> laps: []
                }
            }
            property list<var> alarms: []
            property JsonObject water: JsonObject {
                property int glassesDrunk: 0
                property string lastDate: ""
                property real lastNotify: 0
            }
            property JsonObject media: JsonObject {
            }

            property JsonObject wallpaper: JsonObject {
                property list<string> favourites: []
                property list<string> favouriteDirectories: []
            }
        }
    }
}
