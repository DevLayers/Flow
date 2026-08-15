import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

RippleButton {
    id: root

    required property var displayItem
    property bool active: displayItem ? Boolean(displayItem.isActive) : false
    property bool isStarting: displayItem ? Boolean(displayItem.isStarting) : false
    property bool globallyDisabled: NetworkDisplayService.activeStreamUnit !== "" && !root.active

    signal connectRequested(string uuid)
    signal disconnectRequested()

    implicitHeight: 74
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.normal

    colBackground: root.globallyDisabled
        ? Qt.alpha(Appearance.colors.colLayer1, 0.45)
        : (root.active ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainer, 0.24) : Appearance.colors.colLayer1)
    colBackgroundHover: root.globallyDisabled
        ? Qt.alpha(Appearance.colors.colLayer1, 0.45)
        : (root.active ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainerHover, 0.32) : Appearance.colors.colLayer1Hover)
    colRipple: root.globallyDisabled
        ? "transparent"
        : (root.active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active)

    onClicked: {
        if (root.globallyDisabled)
            return;
        if (root.active) {
            root.disconnectRequested();
        } else {
            root.connectRequested(root.displayItem ? root.displayItem.uuid : "");
        }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.active ? "cast_connected" : (root.displayItem && root.displayItem.protocol === "chromecast" ? "cast" : "tv")
            shape: root.active ? MaterialShape.Shape.Cookie9Sided : MaterialShape.Shape.Clover4Leaf
            iconSize: Appearance.font.pixelSize.large - 2
            padding: 9
            fill: root.active ? 1 : 0
            color: root.active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
            colSymbol: root.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: (root.displayItem && root.displayItem.name) ? root.displayItem.name : Translation.tr("Wireless Receiver")
                font.family: Appearance.font.family.title
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.body
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (root.isStarting)
                        return Translation.tr("Connecting…");
                    if (root.active)
                        return Translation.tr("Connected");
                    if (root.displayItem)
                        return NetworkDisplayService.protocolLabel(root.displayItem.protocol);
                    return Translation.tr("Ready to connect");
                }
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignVCenter
            visible: root.isStarting
            running: root.isStarting
            implicitWidth: 24
            implicitHeight: 24
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            visible: !root.isStarting
            buttonText: root.active ? Translation.tr("Disconnect") : Translation.tr("Connect")
            buttonRadius: Appearance.rounding.small
            colBackground: root.active ? Qt.alpha(Appearance.m3colors.m3error, 0.15) : Appearance.colors.colLayer2
            onClicked: {
                if (root.active) {
                    root.disconnectRequested();
                } else {
                    root.connectRequested(root.displayItem ? root.displayItem.uuid : "");
                }
            }
        }
    }
}
