import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)
    property bool nextButtonHovered: false

    MonitorConfigOption {
        id: monitorConfig
    }

    readonly property var summaryItems: {
        const items = [];
        if (Network.wifiStatus === "connected")
            items.push(Translation.tr("Wi-Fi connected"));
        if (monitorConfig.monitors.length > 0)
            items.push(Translation.tr("%1 displays").arg(String(monitorConfig.monitors.length)));
        items.push(ShellModePolicy.effectiveMode === "connect"
            ? Translation.tr("Connect mode")
            : Translation.tr("Default mode"));
        return items.slice(0, 3);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.rounding.small
        spacing: Appearance.rounding.small

        Item { Layout.fillHeight: true }

        MaterialShape {
            id: completionShape
            Layout.alignment: Qt.AlignHCenter
            implicitSize: Appearance.font.pixelSize.huge * 6
            shape: root.nextButtonHovered
                ? MaterialShape.Shape.Cookie12Sided
                : MaterialShape.Shape.SoftBurst
            color: root.nextButtonHovered
                ? Appearance.colors.colPrimary
                : Appearance.colors.colPrimaryContainer
            scale: 1
            rotation: root.nextButtonHovered ? 12 : 0

            Behavior on rotation {
                enabled: !introAnimation.running
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(completionShape)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            MaterialSymbol {
                id: completionIcon
                anchors.centerIn: parent
                text: "check"
                iconSize: Appearance.font.pixelSize.huge * 2
                color: root.nextButtonHovered
                    ? Appearance.colors.colOnPrimary
                    : Appearance.colors.colOnPrimaryContainer
                rotation: root.nextButtonHovered ? -12 : 0
                scale: 1
                opacity: 1

                Behavior on rotation {
                    enabled: !introAnimation.running
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(completionIcon)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("All set!")
            color: Appearance.colors.colOnLayer0
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.hugeass
            font.variableAxes: Appearance.font.variableAxes.titleRounded
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("You're ready to start using II.")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.large
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.rounding.verysmall

            Repeater {
                model: root.summaryItems

                delegate: Rectangle {
                    required property string modelData
                    radius: Appearance.rounding.full
                    implicitHeight: 28
                    implicitWidth: summaryLabel.implicitWidth + Appearance.rounding.normal
                    color: Appearance.colors.colSecondaryContainer

                    StyledText {
                        id: summaryLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: Appearance.colors.colOnSecondaryContainer
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: WelcomeKeybindRegistry.keysFor("settings").length > 0
            text: Translation.tr("Open Settings any time with %1.")
                .arg(WelcomeKeybindRegistry.keysFor("settings").join(" + "))
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.rounding.small

            RippleButtonWithIcon {
                materialIcon: "settings"
                mainText: Translation.tr("Open Settings")
                centerContent: true
                colText: Appearance.colors.colOnLayer1
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colBackgroundActive: Appearance.colors.colLayer1Active
                colRipple: Appearance.colors.colLayer1Active
                onClicked: root.openSettingsPage("")
            }
        }

        Item { Layout.fillHeight: true }
    }

    SequentialAnimation {
        id: introAnimation

        PropertyAction {
            target: completionShape
            property: "scale"
            value: 0.82
        }
        PropertyAction {
            target: completionShape
            property: "rotation"
            value: -8
        }
        PropertyAction {
            target: completionIcon
            property: "scale"
            value: 0.72
        }
        PropertyAction {
            target: completionIcon
            property: "opacity"
            value: 0
        }
        ParallelAnimation {
            NumberAnimation {
                target: completionShape
                property: "scale"
                to: 1
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
            NumberAnimation {
                target: completionShape
                property: "rotation"
                to: 0
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
        PauseAnimation { duration: Appearance.animation.elementMoveFast.duration }
        ParallelAnimation {
            NumberAnimation {
                target: completionIcon
                property: "scale"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                target: completionIcon
                property: "opacity"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    Component.onCompleted: {
        if (WelcomeMotion.motionEnabled)
            introAnimation.start();
    }
}
