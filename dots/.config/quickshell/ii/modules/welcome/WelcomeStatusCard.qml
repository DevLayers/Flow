import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * A compact, semantic status card used by the Welcome diagnostics page.
 *
 * The card deliberately keeps recovery actions explicit: Settings/tutorial
 * navigation is emitted to the page, while a command is copied without ever
 * executing it.  Diagnostics therefore remain safe to run during first-run.
 */
Rectangle {
    id: root

    property string title: ""
    property string description: ""
    property string statusKind: "optional"
    property string statusLabel: ""
    property string statusIcon: "info"
    property string settingsPage: ""
    property string tutorialId: ""
    property string commandText: ""
    property bool showTutorial: false
    property bool showSettings: false
    property bool showCommand: false
    property bool showRecheck: false

    signal settingsRequested()
    signal tutorialRequested(string tutorialId)
    signal commandRequested(string command)
    signal recheckRequested()

    readonly property color statusContainerColor: {
        switch (root.statusKind) {
        case "ready":
            return Appearance.colors.colPrimaryContainer;
        case "verifying":
            return Appearance.colors.colSecondaryContainer;
        case "dependency":
        case "error":
            return Appearance.colors.colErrorContainer;
        case "attention":
            return Appearance.colors.colTertiaryContainer;
        case "configured":
            return Appearance.colors.colSecondaryContainer;
        default:
            return Appearance.colors.colLayer2;
        }
    }

    readonly property color statusIconColor: {
        switch (root.statusKind) {
        case "ready":
            return Appearance.colors.colPrimary;
        case "verifying":
        case "configured":
            return Appearance.colors.colSecondary;
        case "dependency":
        case "error":
            return Appearance.colors.colError;
        case "attention":
            return Appearance.colors.colTertiary;
        default:
            return Appearance.colors.colOnLayer2;
        }
    }

    readonly property color statusTextColor: {
        switch (root.statusKind) {
        case "ready":
            return Appearance.colors.colOnPrimaryContainer;
        case "verifying":
        case "configured":
            return Appearance.colors.colOnSecondaryContainer;
        case "dependency":
        case "error":
            return Appearance.colors.colOnErrorContainer;
        case "attention":
            return Appearance.colors.colOnTertiaryContainer;
        default:
            return Appearance.colors.colOnLayer2;
        }
    }

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    implicitHeight: cardLayout.implicitHeight + 28
    implicitWidth: 320
    Layout.fillWidth: true

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: root.statusIcon
                shape: MaterialShape.Shape.Cookie7Sided
                iconSize: Appearance.font.pixelSize.large
                padding: 10
                fill: 1
                color: root.statusIconColor
                colSymbol: root.statusContainerColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.description.length > 0
                    text: root.description
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignTop
                text: root.statusLabel
                color: root.statusTextColor
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.showTutorial || root.showSettings || root.showCommand || root.showRecheck

            Item {
                Layout.fillWidth: true
            }

            RippleButtonWithIcon {
                visible: root.showTutorial
                enabled: visible
                implicitHeight: 40
                implicitWidth: 112
                materialIcon: "menu_book"
                mainText: Translation.tr("Tutorial")
                colText: Appearance.colors.colOnLayer2
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundActive: Appearance.colors.colLayer2Active
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.tutorialRequested(root.tutorialId)
            }

            RippleButtonWithIcon {
                visible: root.showSettings
                enabled: visible
                implicitHeight: 40
                implicitWidth: 116
                materialIcon: "settings"
                mainText: Translation.tr("Settings")
                colText: Appearance.colors.colOnLayer2
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundActive: Appearance.colors.colLayer2Active
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.settingsRequested()
            }

            RippleButtonWithIcon {
                visible: root.showCommand
                enabled: root.commandText.length > 0
                implicitHeight: 40
                implicitWidth: 108
                materialIcon: "content_copy"
                mainText: Translation.tr("Copy")
                colText: Appearance.colors.colOnLayer2
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundActive: Appearance.colors.colLayer2Active
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.commandRequested(root.commandText)
            }

            RippleButtonWithIcon {
                visible: root.showRecheck
                enabled: root.statusKind !== "verifying"
                implicitHeight: 40
                implicitWidth: 116
                materialIcon: "refresh"
                mainText: Translation.tr("Check")
                colText: Appearance.colors.colOnLayer2
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundActive: Appearance.colors.colLayer2Active
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.recheckRequested()
            }
        }
    }
}
