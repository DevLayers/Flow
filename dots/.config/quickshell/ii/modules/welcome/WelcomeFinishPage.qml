import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 14

        Item { Layout.fillHeight: true }

        MaterialShape {
            Layout.alignment: Qt.AlignHCenter
        implicitSize: Appearance.font.pixelSize.huge * 6
            shape: MaterialShape.Shape.SoftBurst
            color: Appearance.colors.colPrimaryContainer

            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: Appearance.font.pixelSize.huge * 2
                color: Appearance.colors.colOnPrimaryContainer
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("All set!")
            color: Appearance.colors.colOnLayer0
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("You're ready to start using II.")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.large
            horizontalAlignment: Text.AlignHCenter
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
            spacing: 10

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
}
