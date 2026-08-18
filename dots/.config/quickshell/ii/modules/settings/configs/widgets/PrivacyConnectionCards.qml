pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal configureVpn()
    signal configureTailscale()

    readonly property bool vpnBackendAvailable: VpnService.availableProviders.length > 0
    readonly property string vpnStatus: {
        if (!VpnService.enabled)
            return Translation.tr("Disabled");
        if (VpnService.loading)
            return Translation.tr("Checking connection");
        if (!root.vpnBackendAvailable)
            return Translation.tr("Unavailable");
        if (VpnService.displayActive)
            return Translation.tr("Connected");
        return Translation.tr("Disconnected");
    }
    readonly property string vpnDetail: {
        if (!VpnService.enabled)
            return Translation.tr("VPN integration is turned off");
        if (VpnService.displayActive)
            return VpnService.activeProfile || VpnService.activeProvider || Translation.tr("VPN tunnel active");
        if (!root.vpnBackendAvailable)
            return Translation.tr("No supported VPN backend found");
        return VpnService.statusText || Translation.tr("Ready to connect");
    }

    readonly property string tailscaleStatus: {
        if (!TailscaleService.enabled)
            return Translation.tr("Disabled");
        if (TailscaleService.loading)
            return Translation.tr("Checking connection");
        if (!TailscaleService.available)
            return Translation.tr("Unavailable");
        if (TailscaleService.active)
            return Translation.tr("Connected");
        if (TailscaleService.backendState === "NeedsLogin")
            return Translation.tr("Needs login");
        return TailscaleService.statusText || Translation.tr("Disconnected");
    }
    readonly property string tailscaleDetail: {
        if (!TailscaleService.enabled)
            return Translation.tr("Tailscale integration is turned off");
        if (TailscaleService.active)
            return TailscaleService.nodeName || TailscaleService.tailnetName || Translation.tr("Tailnet connected");
        if (!TailscaleService.available)
            return Translation.tr("The Tailscale command is not available");
        return TailscaleService.statusText || Translation.tr("Ready to connect");
    }

    implicitHeight: cardsLayout.implicitHeight

    component ConnectionCard: Rectangle {
        id: card

        required property string serviceName
        required property string serviceIcon
        required property string status
        required property string detail
        required property bool integrationEnabled
        required property bool connected
        signal integrationToggled(bool enabled)
        signal configure()

        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Appearance.font.pixelSize.large
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: cardLayout

            anchors.fill: parent
            anchors.margins: Appearance.font.pixelSize.small
            spacing: Appearance.font.pixelSize.smallest

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.font.pixelSize.smallest

                MaterialShapeWrappedMaterialSymbol {
                    text: card.serviceIcon
                    iconSize: Appearance.font.pixelSize.large
                    padding: Appearance.font.pixelSize.smallest
                    shape: card.connected ? MaterialShape.Shape.Clover4Leaf : MaterialShape.Shape.Cookie7Sided
                    color: card.connected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
                    colSymbol: card.connected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.serviceName
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }

                StyledSwitch {
                    checked: card.integrationEnabled
                    Accessible.name: Translation.tr("Enable %1 integration").arg(card.serviceName)
                    Accessible.description: Translation.tr("Enable or disable %1 integration").arg(card.serviceName)
                    Accessible.checked: checked
                    onToggled: card.integrationToggled(checked)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.font.pixelSize.smallest

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: statusText.implicitWidth + Appearance.font.pixelSize.normal
                    implicitHeight: statusText.implicitHeight + Appearance.font.pixelSize.smallest
                    radius: Appearance.rounding.full
                    color: card.connected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer

                    StyledText {
                        id: statusText

                        anchors.centerIn: parent
                        text: card.status
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: card.connected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.detail
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: Appearance.font.pixelSize.hugeass * 2
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                Accessible.name: Translation.tr("Configure %1").arg(card.serviceName)
                Accessible.description: Translation.tr("Open configuration for %1. Current status: %2").arg(card.serviceName).arg(card.status)
                onClicked: card.configure()

                contentItem: Item {
                    implicitWidth: configureContent.implicitWidth
                    implicitHeight: configureContent.implicitHeight

                    RowLayout {
                        id: configureContent
                        anchors.centerIn: parent
                        spacing: Appearance.font.pixelSize.smallest

                        MaterialSymbol {
                            text: "tune"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        StyledText {
                            text: Translation.tr("Configure")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }
        }
    }

    GridLayout {
        id: cardsLayout

        anchors.left: parent.left
        anchors.right: parent.right
        columns: width >= Appearance.font.pixelSize.hugeass * 18 ? 2 : 1
        columnSpacing: Appearance.font.pixelSize.smallest
        rowSpacing: Appearance.font.pixelSize.smallest

        ConnectionCard {
            serviceName: Translation.tr("VPN")
            serviceIcon: "vpn_lock"
            status: root.vpnStatus
            detail: root.vpnDetail
            integrationEnabled: VpnService.enabled
            connected: VpnService.enabled && VpnService.displayActive
            onIntegrationToggled: enabled => Config.options.vpn.enabled = enabled
            onConfigure: root.configureVpn()
        }

        ConnectionCard {
            serviceName: Translation.tr("Tailscale")
            serviceIcon: "hub"
            status: root.tailscaleStatus
            detail: root.tailscaleDetail
            integrationEnabled: TailscaleService.enabled
            connected: TailscaleService.enabled && TailscaleService.active
            onIntegrationToggled: enabled => Config.options.tailscale.enabled = enabled
            onConfigure: root.configureTailscale()
        }
    }
}
