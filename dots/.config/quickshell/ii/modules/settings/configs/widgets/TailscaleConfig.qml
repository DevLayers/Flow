import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false
    property bool showBackButton: false
    signal goBack()

    RowLayout {
        visible: root.showBackButton
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }

            onClicked: root.goBack()
        }

        StyledText {
            text: Translation.tr("Tailscale Mesh Settings")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "hub"
        title: Translation.tr("Mesh Network & Nodes")

        NoticeBox {
            Layout.fillWidth: true
            isFirst: true
            text: Translation.tr("Tailscale builds a secure peer-to-peer mesh VPN between your phone, laptop, and servers using WireGuard.")
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Stop tailscaled when integration is disabled")
            checked: Config.options.tailscale.stopDaemonWhenDisabled
            onCheckedChanged: Config.options.tailscale.stopDaemonWhenDisabled = checked
            StyledToolTip { text: Translation.tr("Uses polkit to stop/start the tailscaled system service. Authentication may be required.") }
        }

        ConfigSwitch {
            buttonIcon: "dns"
            text: Translation.tr("Accept MagicDNS")
            checked: Config.options.tailscale.acceptDns
            onCheckedChanged: {
                Config.options.tailscale.acceptDns = checked;
            }
            StyledToolTip {
                text: Translation.tr("Resolves tailnet hostnames automatically using Tailscale DNS.")
            }
        }

        ConfigSwitch {
            buttonIcon: "security"
            text: Translation.tr("Shields-up (block incoming)")
            checked: Config.options.tailscale.shieldsUp
            onCheckedChanged: {
                Config.options.tailscale.shieldsUp = checked;
            }
            StyledToolTip {
                text: Translation.tr("Blocks incoming connections from other devices on your Tailnet.")
            }
        }

        ConfigSwitch {
            buttonIcon: "terminal"
            text: Translation.tr("Tailscale SSH")
            checked: Config.options.tailscale.ssh
            onCheckedChanged: {
                Config.options.tailscale.ssh = checked;
            }
            StyledToolTip {
                text: Translation.tr("Allows secure SSH access from authenticated devices in your tailnet.")
            }
        }

        ConfigSwitch {
            buttonIcon: "autorenew"
            text: Translation.tr("Connect Tailscale automatically")
            checked: Config.options.tailscale.autoConnect
            onCheckedChanged: Config.options.tailscale.autoConnect = checked
        }

        ConfigSwitch {
            buttonIcon: "group"
            text: Translation.tr("Show tailnet peers")
            checked: Config.options.tailscale.showPeers
            onCheckedChanged: Config.options.tailscale.showPeers = checked
        }

        ConfigSwitch {
            buttonIcon: "output"
            text: Translation.tr("Advertise this device as an exit node")
            checked: Config.options.tailscale.advertiseExitNode
            onCheckedChanged: Config.options.tailscale.advertiseExitNode = checked
        }

        ConfigTextField {
            icon: "alt_route"
            text: Translation.tr("Advertise subnet routes")
            placeholderText: Translation.tr("CIDRs separated by commas, e.g. 192.168.1.0/24")
            inputText: (Config.options.tailscale.advertiseRoutes || []).join(", ")
            textField.onTextChanged: {
                Config.options.tailscale.advertiseRoutes = textField.text.split(",")
                    .map(route => route.trim()).filter(route => route.length > 0)
            }
        }

        ConfigSwitch {
            buttonIcon: "troubleshoot"
            text: Translation.tr("Enable Tailscale diagnostics")
            checked: Config.options.tailscale.enableDiagnostics
            onCheckedChanged: Config.options.tailscale.enableDiagnostics = checked
        }

        TipBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Tailscale Setup: Install tailscale daemon ('sudo dnf install tailscale && sudo systemctl enable --now tailscaled'). Run 'tailscale up' to authenticate.")
        }
    }
}
