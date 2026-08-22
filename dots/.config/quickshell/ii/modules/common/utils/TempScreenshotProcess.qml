import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Process {
    id: screenshotProc
    running: true
    property string screenshotDir: Directories.screenshotTemp
    required property ShellScreen screen
    property string screenshotPath: `${screenshotDir}/image-${screen.name}`
    property bool completed: false
    property int startedToken: 0
    property bool restarting: false
    // grim output format. ppm skips PNG compression, which is the slow part of
    // grim, but the file is then only safe for consumers that sniff the format
    // (magick/Qt/OpenCV). Anything shipping the bytes as-is to an external API
    // must stay on png, so this is opt-in rather than the default.
    property string format: "png"
    command: ["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(screenshotDir)}' && exec grim -t ${StringUtils.shellSingleQuoteEscape(format)} -o '${StringUtils.shellSingleQuoteEscape(screen.name)}' '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`]

    onRunningChanged: {
        if (running) {
            screenshotProc.completed = false;
            return;
        }
        if (screenshotProc.restarting || screenshotProc.startedToken === 0)
            return;
        screenshotProc.completed = true;
    }

    function recapture(token) {
        screenshotProc.completed = false;
        screenshotProc.startedToken = token;
        if (screenshotProc.running) {
            screenshotProc.restarting = true;
            screenshotProc.running = false;
            screenshotProc.restarting = false;
        }
        screenshotProc.running = true;
    }
}
