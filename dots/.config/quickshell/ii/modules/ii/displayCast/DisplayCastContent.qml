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
        NetworkDisplayService.ensureBackend();
        NetworkDisplayService.runDiagnostics();
        DisplayProjectionService.fetchMonitors();
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

                // ── Header ──────────────────────────────────────────────────
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

                // ── Physical Projection Modes ───────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !Config.options.displayCast || Config.options.displayCast.showProjectionModes !== false

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

                // ── Active Cast Card ────────────────────────────────────────
                ActiveCastCard {
                    Layout.fillWidth: true
                    visible: NetworkDisplayService.activeStreamUnit !== "" || NetworkDisplayService.sessionState === "Starting" || NetworkDisplayService.sessionState === "SessionActive"
                }

                // ── Wireless Displays ───────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !Config.options.displayCast || Config.options.displayCast.wirelessEnabled !== false

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Wireless Displays")
                            font.family: Appearance.font.family.title
                            font.weight: Font.Bold
                            font.pixelSize: Appearance.font.pixelSize.body
                            color: Appearance.colors.colOnLayer0
                        }

                        RippleButton {
                            buttonText: Translation.tr("Refresh")
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer2
                            onClicked: {
                                NetworkDisplayService.startDiscovery();
                            }
                        }
                    }

                    // Empty or backend status
                    WirelessBackendStatus {
                        Layout.fillWidth: true
                        visible: !NetworkDisplayService.backendInstalled || NetworkDisplayService.filteredDisplays.length === 0 || (NetworkDisplayService.sessionState === "Error" && NetworkDisplayService.activeStreamUnit === "")
                    }

                    // Sink List
                    Repeater {
                        model: NetworkDisplayService.filteredDisplays
                        delegate: WirelessDisplayDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            displayItem: modelData
                            onConnectRequested: uuid => NetworkDisplayService.connectTo(uuid)
                            onDisconnectRequested: () => NetworkDisplayService.disconnect()
                        }
                    }
                }

                // ── Footer ──────────────────────────────────────────────────
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
