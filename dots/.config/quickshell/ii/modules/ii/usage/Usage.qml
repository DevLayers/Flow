import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

/**
 * The usage overlay: per-app screen time and energy, on Super+U.
 *
 * Same shape as the cheatsheet — one centred surface on the overlay layer, held
 * open by a focus grab and dismissed by anything that takes focus away. The whole
 * window is torn down on close rather than merely hidden, so the histogram and the
 * app list cost nothing while it is shut.
 */
Scope {
    id: root

    property bool activeState: false

    Connections {
        target: GlobalStates

        function onUsageOpenChanged() {
            if (GlobalStates.usageOpen && !root.activeState) {
                root.requestOpen();
            } else if (!GlobalStates.usageOpen && root.activeState) {
                root.requestClose();
            }
        }
    }

    // Outlives the close animation, so the surface is not destroyed mid-fade.
    Timer {
        id: closeTimer
        interval: 400
        onTriggered: root.activeState = false
    }

    function requestOpen() {
        closeTimer.stop();
        root.activeState = true;
        GlobalStates.usageOpen = true;
    }

    function requestClose() {
        GlobalStates.usageOpen = false;
        closeTimer.start();
    }

    function requestToggle() {
        if (GlobalStates.usageOpen) {
            root.requestClose();
        } else {
            root.requestOpen();
        }
    }

    Loader {
        id: usageLoader
        active: root.activeState

        sourceComponent: PanelWindow {
            id: usageRoot

            visible: usageLoader.active
            color: "transparent"
            exclusiveZone: 0
            implicitWidth: usageBackground.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: usageBackground.height + Appearance.sizes.elevationMargin * 2

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "quickshell:usage"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.usageOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Clicks outside the panel belong to whatever is underneath.
            mask: Region {
                item: usageInputMask
            }

            function hide() {
                root.requestClose();
            }

            // Registering the grab immediately would catch the keypress that opened
            // the overlay and close it again.
            Timer {
                id: registerGrabTimer
                interval: 150
                onTriggered: GlobalFocusGrab.addDismissable(usageRoot)
            }

            Component.onCompleted: registerGrabTimer.start()

            Component.onDestruction: {
                registerGrabTimer.stop();
                GlobalFocusGrab.removeDismissable(usageRoot);
            }

            Connections {
                target: GlobalFocusGrab

                function onDismissed() {
                    usageRoot.hide();
                }
            }

            onVisibleChanged: {
                if (visible)
                    initialFocusTimer.restart();
            }

            Timer {
                id: initialFocusTimer
                interval: 50
                onTriggered: usageBackground.forceActiveFocus()
            }

            Item {
                id: usageInputMask
                anchors.centerIn: parent
                width: usageBackground.width
                height: usageBackground.height
            }

            Item {
                id: dialogWrap
                anchors.fill: parent
                transformOrigin: Item.Center
                scale: usageBackground.animateIn && GlobalStates.usageOpen ? 1.0 : 0.94
                opacity: usageBackground.animateIn && GlobalStates.usageOpen ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasized
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasized
                    }
                }

                StyledRectangularShadow {
                    target: usageBackground
                }

                Rectangle {
                    id: usageBackground

                    property real padding: 20
                    property bool animateIn: false
                    readonly property real maxBgWidth: usageRoot.screen ? usageRoot.screen.width * 0.95 : 1900
                    readonly property real maxBgHeight: usageRoot.screen ? usageRoot.screen.height * 0.80 : 1000

                    anchors.centerIn: parent
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.windowRounding
                    implicitWidth: Math.min(maxBgWidth, usageColumnLayout.implicitWidth + padding * 2)
                    implicitHeight: Math.min(maxBgHeight, usageColumnLayout.implicitHeight + padding * 2)

                    // Held back one frame so the panel is laid out before it moves.
                    Timer {
                        id: animDelayTimer
                        interval: 80
                        running: true
                        onTriggered: usageBackground.animateIn = true
                    }

                    Keys.onPressed: event => {
                        if (event.key !== Qt.Key_Escape)
                            return;
                        usageRoot.hide();
                        event.accepted = true;
                    }

                    RippleButton {
                        id: closeButton

                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.rounding.full
                        scale: usageBackground.animateIn ? 1.0 : 0.0
                        onClicked: usageRoot.hide()

                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 20
                            rightMargin: 20
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.5
                            }
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.title
                            text: "close"
                            rotation: closeButton.isHovered ? 90 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: usageColumnLayout

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - parent.padding * 2)
                        height: Math.min(implicitHeight, parent.height - parent.padding * 2)
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: 52
                            spacing: 10

                            MaterialSymbol {
                                text: "bar_chart"
                                iconSize: Appearance.font.pixelSize.huge
                                color: Appearance.colors.colOnLayer0
                            }

                            StyledText {
                                text: Translation.tr("App usage")
                                font.pixelSize: Appearance.font.pixelSize.huge
                                color: Appearance.colors.colOnLayer0
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // The energy source decides whether watt-hours are real
                            // counters or a battery-drain guess, so it is stated
                            // rather than left for the user to infer.
                            StyledText {
                                visible: AppStats.running
                                text: {
                                    switch (AppStats.source) {
                                    case "rapl":
                                        return Translation.tr("Energy from RAPL counters");
                                    case "battery":
                                        return Translation.tr("Energy estimated from battery drain");
                                    default:
                                        return Translation.tr("Energy unavailable");
                                    }
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        UsageContent {
                            id: usageContent

                            readonly property real calculatedWidth: usageRoot.screen ? usageRoot.screen.width * 0.92 : 1700
                            readonly property real calculatedHeight: usageRoot.screen ? usageRoot.screen.height * 0.62 : 650

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.min(1500, Math.max(900, calculatedWidth))
                            Layout.preferredHeight: Math.min(700, Math.max(460, calculatedHeight))
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "usage"

        function toggle(): void {
            root.requestToggle();
        }

        function open(): void {
            root.requestOpen();
        }

        function close(): void {
            root.requestClose();
        }
    }

    GlobalShortcut {
        name: "usageToggle"
        description: "Toggles the app usage overlay on press"
        onPressed: root.requestToggle()
    }

    GlobalShortcut {
        name: "usageOpen"
        description: "Opens the app usage overlay on press"
        onPressed: root.requestOpen()
    }

    GlobalShortcut {
        name: "usageClose"
        description: "Closes the app usage overlay on press"
        onPressed: root.requestClose()
    }
}
