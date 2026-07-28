pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal dismissed()

    readonly property bool isHovered: backgroundMa.containsMouse

    property bool _closing: false

    Timer {
        id: dismissTimer
        interval: 4000
        repeat: false
        running: !isHovered
        onTriggered: root._startClose()
    }

    onIsHoveredChanged: {
        if (isHovered) dismissTimer.stop()
        else dismissTimer.restart()
    }

    Connections {
        target: GlobalStates
        function onScreenshotOverlayImagePathChanged() {
            if (GlobalStates.screenshotOverlayImagePath !== "") {
                dismissTimer.restart();
            }
        }
    }

    property real horizontalPadding: 12
    property real verticalPadding: 12
    property real maxPreviewWidth: 320
    property real maxPreviewHeight: 200

    // Preview size based on REGION aspect ratio (not full image)
    property real regionAspect: {
        var rw = GlobalStates.screenshotOverlayRegionW;
        var rh = GlobalStates.screenshotOverlayRegionH;
        if (rw > 0 && rh > 0) return rw / rh;
        var iw = previewImage.sourceSize.width;
        var ih = previewImage.sourceSize.height;
        if (iw > 0 && ih > 0) return iw / ih;
        return 16 / 9;
    }
    property real previewW: Math.min(maxPreviewWidth, maxPreviewHeight * regionAspect)
    property real previewH: previewW / regionAspect

    // Fixed button dimensions
    readonly property real saveBtnWidth: 110
    readonly property real iconBtnWidth: 42
    readonly property real toolbarHeight: 44
    readonly property real toolbarSpacing: 4
    readonly property real toolbarInnerPadding: 6

    property real toolbarW: saveBtnWidth + iconBtnWidth * 2 + toolbarSpacing * 2 + toolbarInnerPadding * 2

    implicitWidth: Math.max(previewW, toolbarW) + 2 * horizontalPadding + 2 * Appearance.sizes.elevationMargin
    implicitHeight: previewH + toolbarHeight + verticalPadding * 2 + 8 + 2 * Appearance.sizes.elevationMargin

    // Open animation
    NumberAnimation on opacity {
        from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic
    }
    NumberAnimation on x {
        from: -400; to: 0; duration: 400; easing.type: Easing.OutCubic
    }

    // Close animation
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; from: 1; to: 0; duration: 300; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "x"; from: 0; to: -400; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.dismissed() }
    }

    function _startClose() {
        if (root._closing) return;
        root._closing = true;
        closeAnim.start();
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        spacing: 8

        // Preview — shows cropped region using sourceSize-based positioning
        Item {
            Layout.preferredWidth: root.previewW
            Layout.preferredHeight: root.previewH
            Layout.alignment: Qt.AlignLeft

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.windowRounding
                color: "transparent"
                border.width: 4
                border.color: Appearance.colors.colPrimaryContainer
                clip: true

                Image {
                    id: previewImage
                    source: GlobalStates.screenshotOverlayImagePath !== ""
                        ? "file://" + GlobalStates.screenshotOverlayImagePath
                        : ""
                    asynchronous: true
                    smooth: true
                    visible: sourceSize.width > 0 && sourceSize.height > 0

                    // Region-based crop positioning
                    property real _regionW: GlobalStates.screenshotOverlayRegionW > 0 ? GlobalStates.screenshotOverlayRegionW : sourceSize.width
                    property real _regionH: GlobalStates.screenshotOverlayRegionH > 0 ? GlobalStates.screenshotOverlayRegionH : sourceSize.height
                    property real _regionX: GlobalStates.screenshotOverlayRegionW > 0 ? GlobalStates.screenshotOverlayRegionX : 0
                    property real _regionY: GlobalStates.screenshotOverlayRegionH > 0 ? GlobalStates.screenshotOverlayRegionY : 0

                    property real _scale: {
                        if (_regionW <= 0 || _regionH <= 0 || root.previewW <= 0 || root.previewH <= 0) return 1;
                        return Math.max(root.previewW / _regionW, root.previewH / _regionH);
                    }

                    width: sourceSize.width * _scale
                    height: sourceSize.height * _scale
                    x: -(_regionX * _scale) + (root.previewW - _regionW * _scale) / 2
                    y: -(_regionY * _scale) + (root.previewH - _regionH * _scale) / 2
                }
            }
        }

        // Toolbar — left-aligned, compact spacing
        Rectangle {
            id: toolbar
            Layout.preferredWidth: root.toolbarW
            Layout.preferredHeight: root.toolbarHeight
            Layout.alignment: Qt.AlignLeft
            radius: height / 2
            color: Appearance.colors.colPrimaryContainer

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.toolbarInnerPadding
                    rightMargin: root.toolbarInnerPadding
                }
                spacing: root.toolbarSpacing

                // Save button
                Rectangle {
                    id: saveButton
                    Layout.preferredWidth: root.saveBtnWidth
                    Layout.fillHeight: true
                    radius: height / 2
                    color: saveMa.containsMouse ? Qt.lighter(Appearance.colors.colPrimary, 1.15) : Appearance.colors.colPrimary
                    scale: saveMa.pressed ? 0.93 : (saveMa.containsMouse ? 1.04 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: "save"
                            iconSize: 18
                            color: Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: Translation.tr("Save")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    MouseArea {
                        id: saveMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            console.log("[ScreenshotOverlay] Save clicked");
                            var esc = function(s) { return String(s).replace(/'/g, "'\\''"); };
                            var saveDir = Config.options.screenSnip.savePath || (Directories.home + "/Pictures/Screenshots");
                            var timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh.mm.ss");
                            var fullPath = saveDir + "/screenshot-" + timestamp + ".png";
                            var cmd = "mkdir -p '" + esc(saveDir) + "' && ";
                            if (GlobalStates.screenshotOverlayRegionW > 0) {
                                cmd += "magick '" + esc(GlobalStates.screenshotOverlayImagePath) + "' -crop " +
                                    String(GlobalStates.screenshotOverlayRegionW) + "x" + String(GlobalStates.screenshotOverlayRegionH) + "+" +
                                    String(GlobalStates.screenshotOverlayRegionX) + "+" + String(GlobalStates.screenshotOverlayRegionY) + " +repage '" + esc(fullPath) + "'";
                            } else {
                                cmd += "cp '" + esc(GlobalStates.screenshotOverlayImagePath) + "' '" + esc(fullPath) + "'";
                            }
                            cmd += " && notify-send -i camera-photo -t 3000 --hint=boolean:suppress-sound:true 'Screenshot saved' 'Saved to: " + esc(fullPath) + "'";
                            console.log("[ScreenshotOverlay] Save cmd:", cmd);
                            Quickshell.execDetached(["bash", "-c", cmd]);
                            root._startClose();
                        }
                    }

                    // Tooltip
                    Rectangle {
                        visible: saveMa.containsMouse
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 6
                        color: Appearance.colors.colLayer0
                        width: tooltipSaveText.implicitWidth + 16
                        height: tooltipSaveText.implicitHeight + 10

                        StyledText {
                            id: tooltipSaveText
                            text: Translation.tr("Save to file")
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            anchors.centerIn: parent
                        }
                    }
                }

                // Edit button
                Rectangle {
                    id: editButton
                    Layout.preferredWidth: root.iconBtnWidth
                    Layout.fillHeight: true
                    radius: height / 2
                    color: editMa.containsMouse ? Qt.lighter(Appearance.colors.colPrimary, 1.15) : Appearance.colors.colPrimary
                    scale: editMa.pressed ? 0.93 : (editMa.containsMouse ? 1.04 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                    MaterialSymbol {
                        text: "edit"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimary
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: editMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            console.log("[ScreenshotOverlay] Edit clicked");
                            var esc = function(s) { return String(s).replace(/'/g, "'\\''"); };
                            var cmd = "";
                            if (GlobalStates.screenshotOverlayRegionW > 0) {
                                var tempPath = "/tmp/quickshell-snip-edit-" + Date.now() + ".png";
                                cmd = "magick '" + esc(GlobalStates.screenshotOverlayImagePath) + "' -crop " +
                                    String(GlobalStates.screenshotOverlayRegionW) + "x" + String(GlobalStates.screenshotOverlayRegionH) + "+" +
                                    String(GlobalStates.screenshotOverlayRegionX) + "+" + String(GlobalStates.screenshotOverlayRegionY) + " +repage '" + esc(tempPath) + "' && swappy -f '" + esc(tempPath) + "'";
                            } else {
                                cmd = "swappy -f '" + esc(GlobalStates.screenshotOverlayImagePath) + "'";
                            }
                            console.log("[ScreenshotOverlay] Edit cmd:", cmd);
                            Quickshell.execDetached(["bash", "-c", cmd]);
                            root._startClose();
                        }
                    }

                    Rectangle {
                        visible: editMa.containsMouse
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 6
                        color: Appearance.colors.colLayer0
                        width: tooltipEditText.implicitWidth + 16
                        height: tooltipEditText.implicitHeight + 10

                        StyledText {
                            id: tooltipEditText
                            text: Translation.tr("Edit with swappy")
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            anchors.centerIn: parent
                        }
                    }
                }

                // Delete button
                Rectangle {
                    id: deleteButton
                    Layout.preferredWidth: root.iconBtnWidth
                    Layout.fillHeight: true
                    radius: height / 2
                    color: deleteMa.containsMouse ? Qt.lighter(Appearance.colors.colPrimary, 1.15) : Appearance.colors.colPrimary
                    scale: deleteMa.pressed ? 0.93 : (deleteMa.containsMouse ? 1.04 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                    MaterialSymbol {
                        text: "delete"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimary
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: deleteMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            console.log("[ScreenshotOverlay] Delete clicked");
                            Quickshell.execDetached(["bash", "-c", "wl-copy --clear"]);
                            root._startClose();
                        }
                    }

                    Rectangle {
                        visible: deleteMa.containsMouse
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 6
                        color: Appearance.colors.colLayer0
                        width: tooltipDeleteText.implicitWidth + 16
                        height: tooltipDeleteText.implicitHeight + 10

                        StyledText {
                            id: tooltipDeleteText
                            text: Translation.tr("Clear clipboard")
                            font.pixelSize: 11
                            color: Appearance.colors.colOnLayer0
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: backgroundMa
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        onClicked: root._startClose()
    }
}
