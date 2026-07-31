pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

/**
 * Periodically samples the current video frame playing in mpvpaper via mpv IPC,
 * extracts the dominant color using Python PIL, and emits dynamic colors.
 */
Singleton {
    id: root

    property bool active: false
    property string ipcSocket: ""
    property int samplingInterval: Config.options.background.mediaMode.musicVideo.videoSamplingInterval ?? 1000

    property color currentExtractedColor: Appearance.colors.colPrimary

    readonly property string framePath: "/tmp/ii-videoframe.png"
    property bool _busy: false

    Timer {
        id: sampleTimer
        interval: Math.max(100, root.samplingInterval)
        running: root.active || MusicVideoService.videoPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root._busy)
                return;
            const sock = root.ipcSocket || MusicVideoService.ipcSocket || "/tmp/ii-musicvideo.sock";
            root._busy = true;

            const scriptPath = Directories.scriptPath + "/colors/video_frame_color.py";
            const screenshotCmd = '{"command":["screenshot-to-file","' + root.framePath + '","video"]}';
            
            // Single pipeline: screenshot via mpv socket → run python color extraction → stdout
            samplerProc.command = [
                "bash", "-c",
                "echo '" + screenshotCmd.replace(/'/g, "'\\''") + "' | socat - UNIX-CONNECT:" + sock + " >/dev/null 2>&1; sleep 0.1; [ -f '" + root.framePath + "' ] && python3 '" + scriptPath + "' '" + root.framePath + "'"
            ];
            samplerProc.running = false;
            samplerProc.running = true;
        }
    }

    Process {
        id: samplerProc
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                const hex = String(data).trim();
                if (hex.startsWith("#") && hex.length === 7) {
                    root.currentExtractedColor = Qt.color(hex);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root._busy = false;
        }
    }

    // Safety guard: reset busy flag if process gets stuck for over 3 seconds
    Timer {
        interval: 3000
        running: root._busy
        repeat: false
        onTriggered: {
            root._busy = false;
        }
    }
}
