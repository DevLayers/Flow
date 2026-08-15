import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    implicitWidth: parent ? parent.width : 340
    implicitHeight: layout.implicitHeight + 28
    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1

    readonly property bool backendReady: NetworkDisplayService.backendInstalled || NetworkDisplayService.managerAvailable
    readonly property bool isError: NetworkDisplayService.sessionState === "Error"

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.isError ? "error" : (root.backendReady ? "cast" : "cast_pause")
                shape: MaterialShape.Shape.Cookie9Sided
                iconSize: Appearance.font.pixelSize.large
                padding: 10
                fill: 1
                color: root.isError
                    ? Qt.alpha(Appearance.m3colors.m3error, 0.18)
                    : Appearance.colors.colSecondaryContainer
                colSymbol: root.isError
                    ? Appearance.m3colors.m3error
                    : Appearance.colors.colOnSecondaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.isError)
                            return Translation.tr("Casting error");
                        if (root.backendReady)
                            return Translation.tr("No displays detected");
                        return Translation.tr("Wireless displays unavailable");
                    }
                    font.family: Appearance.font.family.title
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.body
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.isError)
                            return NetworkDisplayService.lastError || Translation.tr("An unexpected casting error occurred.");
                        if (root.backendReady)
                            return Translation.tr("Make sure your receiver or TV is on and connected to the same network.");
                        return Translation.tr("GNOME Network Displays was not found on your system.");
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: root.backendReady
                buttonText: Translation.tr("Open App")
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    NetworkDisplayService.launchBackendApp();
                }
            }

            RippleButton {
                visible: root.backendReady
                buttonText: Translation.tr("Scan")
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    NetworkDisplayService.startDiscovery();
                }
            }

            RippleButton {
                visible: !root.backendReady
                buttonText: Translation.tr("Display settings")
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: {
                    GlobalStates.openSettingsPage("displays");
                    GlobalStates.closeDisplayCast();
                }
            }
        }
    }
}
