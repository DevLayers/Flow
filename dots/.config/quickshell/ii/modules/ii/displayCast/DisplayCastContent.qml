import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal dismissRequested()

    property real contentWidth: 420
    property real horizontalPadding: 16
    property real verticalPadding: 16

    Component.onCompleted: {
        DisplayProjectionService.fetchMonitors();
        SunshineService.refresh();
    }

    implicitWidth: contentWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: Math.min(680, contentLayout.implicitHeight + verticalPadding * 2 + 2 * Appearance.sizes.elevationMargin)

    property alias staticMaskTarget: staticMaskTarget
    Item {
        id: staticMaskTarget
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
    }

    StyledRectangularShadow {
        target: contentBackground
    }

    Rectangle {
        id: contentBackground
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        radius: Appearance.rounding.large
        color: Config.options.appearance.transparency.popups ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer

        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: contentLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentLayout
                width: flickable.width
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "devices"
                        shape: MaterialShape.Shape.Cookie9Sided
                        iconSize: Appearance.font.pixelSize.large
                        padding: 10
                        fill: 1
                        color: Appearance.colors.colPrimaryContainer
                        colSymbol: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Display & Cast")
                        font.family: Appearance.font.family.title
                        font.weight: Font.Bold
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer0
                    }

                    RippleButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        onClicked: root.dismissRequested()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Projection Modes")
                            font.family: Appearance.font.family.title
                            font.weight: Font.Bold
                            font.pixelSize: Appearance.font.pixelSize.body
                            color: Appearance.colors.colOnLayer0
                        }

                        RippleButton {
                            visible: DisplayProjectionService.hasSnapshot
                            buttonText: Translation.tr("Restore")
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer2
                            onClicked: DisplayProjectionService.restoreSnapshot()
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        ProjectionModeCard {
                            Layout.fillWidth: true
                            modeIcon: "laptop"
                            title: Translation.tr("Primary only")
                            description: DisplayProjectionService.primaryMonitorName
                            active: DisplayProjectionService.currentMode === "primaryOnly"
                            onTriggered: DisplayProjectionService.applyPrimaryOnly()
                        }

                        ProjectionModeCard {
                            Layout.fillWidth: true
                            modeIcon: "content_copy"
                            title: Translation.tr("Duplicate")
                            description: Translation.tr("Mirror display")
                            enabled: DisplayProjectionService.hasExternalMonitors
                            active: DisplayProjectionService.currentMode === "duplicate"
                            onTriggered: DisplayProjectionService.applyDuplicate()
                        }

                        ProjectionModeCard {
                            Layout.fillWidth: true
                            modeIcon: "view_week"
                            title: Translation.tr("Extend")
                            description: Translation.tr("Spread workspace")
                            enabled: DisplayProjectionService.hasExternalMonitors
                            active: DisplayProjectionService.currentMode === "extend"
                            onTriggered: DisplayProjectionService.applyExtend()
                        }

                        ProjectionModeCard {
                            Layout.fillWidth: true
                            modeIcon: "desktop_windows"
                            title: Translation.tr("External only")
                            description: Translation.tr("Second screen")
                            enabled: DisplayProjectionService.hasExternalMonitors
                            active: DisplayProjectionService.currentMode === "externalOnly"
                            onTriggered: DisplayProjectionService.applyExternalOnly()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Remote Streaming")
                            font.family: Appearance.font.family.title
                            font.weight: Font.Bold
                            font.pixelSize: Appearance.font.pixelSize.body
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            text: {
                                if (!SunshineService.installed)
                                    return Translation.tr("Unavailable");
                                return SunshineService.running ? Translation.tr("Ready") : Translation.tr("Stopped");
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: SunshineService.running ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: sunshineLayout.implicitHeight + 24
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colLayer1

                        RowLayout {
                            id: sunshineLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: SunshineService.running ? "cast_connected" : "cast"
                                shape: MaterialShape.Shape.Cookie9Sided
                                iconSize: Appearance.font.pixelSize.large
                                padding: 9
                                fill: SunshineService.running ? 1 : 0
                                color: SunshineService.running ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
                                colSymbol: SunshineService.running ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: SunshineService.installed
                                        ? Translation.tr("Sunshine")
                                        : Translation.tr("Sunshine not detected")
                                    font.family: Appearance.font.family.title
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.body
                                    color: Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!SunshineService.installed)
                                            return Translation.tr("Install Sunshine to stream with Moonlight.");
                                        if (SunshineService.hostAddress.length > 0)
                                            return Translation.tr("Moonlight host: %1").arg(SunshineService.hostAddress);
                                        return Translation.tr("Low-latency host for Moonlight clients");
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }

                            RippleButton {
                                visible: SunshineService.serviceAvailable
                                buttonText: SunshineService.running ? Translation.tr("Stop") : Translation.tr("Start")
                                buttonRadius: Appearance.rounding.small
                                enabled: !SunshineService.actionRunning && !SunshineService.refreshing
                                onClicked: SunshineService.setRunning(!SunshineService.running)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RippleButtonWithIcon {
                            Layout.fillWidth: true
                            materialIcon: "open_in_new"
                            mainText: Translation.tr("Sunshine Web UI")
                            centerContent: true
                            enabled: SunshineService.installed
                            onClicked: SunshineService.openWebUi()
                        }

                        RippleButtonWithIcon {
                            Layout.fillWidth: true
                            materialIcon: "refresh"
                            mainText: Translation.tr("Refresh")
                            centerContent: true
                            enabled: !SunshineService.refreshing && !SunshineService.actionRunning
                            onClicked: SunshineService.refresh()
                        }
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: "settings"
                    mainText: Translation.tr("Display Settings")
                    centerContent: true
                    buttonRadius: Appearance.rounding.normal
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: {
                        GlobalStates.openSettingsPage("displays");
                        root.dismissRequested();
                    }
                }
            }
        }
    }
}
