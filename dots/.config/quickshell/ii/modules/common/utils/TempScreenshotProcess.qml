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
    property string screenshotPath: `${screenshotDir}/image-${screen.name}.ppm`
    property bool completed: false
    property int startedToken: 0
    property bool restarting: false
    // ppm skips PNG compression, which is the slow part of grim. Magick/Qt/OpenCV
    // all sniff the format, and ScreenshotAction forces png:- on clipboard output.
    command: ["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(screenshotDir)}' && exec grim -t ppm -o '${StringUtils.shellSingleQuoteEscape(screen.name)}' '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`]

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
