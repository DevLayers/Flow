import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: privacyRoot
    anchors.fill: parent

    property alias contentY: root.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: root
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        ContentSection {
            icon: "policy"
            title: Translation.tr("Work Safety & Policies")

            ContentSubsectionLabel { text: Translation.tr("Hiding Suspects") }

            ConfigSwitch {
                buttonIcon: "assignment"
                text: Translation.tr("Hide clipboard images")
                checked: Config.options.workSafety.enable.clipboard
                onCheckedChanged: {
                    Config.options.workSafety.enable.clipboard = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Hide suspect/anime wallpapers")
                checked: Config.options.workSafety.enable.wallpaper
                onCheckedChanged: {
                    Config.options.workSafety.enable.wallpaper = checked;
                }
            }
        }

        ContentSection {
            icon: "vpn_lock"
            title: Translation.tr("VPN Settings")

            ConfigSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Enable VPN Integration")
                checked: Config.options.vpn.enabled
                configPage: Qt.resolvedUrl("widgets/VPNConfig.qml")
                onCheckedChanged: {
                    Config.options.vpn.enabled = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Toggle VPN service. Click button text to configure profiles, providers, kill switch, and auto-connect.")
                }
            }
        }

        ContentSection {
            icon: "hub"
            title: Translation.tr("Tailscale Mesh Settings")

            ConfigSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Enable Tailscale Integration")
                checked: Config.options.tailscale.enabled
                configPage: Qt.resolvedUrl("widgets/TailscaleConfig.qml")
                onCheckedChanged: {
                    Config.options.tailscale.enabled = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Toggle Tailscale monitoring. Click button text to configure MagicDNS, SSH, exit nodes, and subnets.")
                }
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("The Weeb (NSFW) sidebar tab can be toggled from the Sidebars page.")
        }

        ContentSection {
            icon: "link"
            title: Translation.tr("Related settings")

            Flow {
                Layout.fillWidth: true
                spacing: 8

                RelatedChip {
                    pageId: "clipboard"
                    label: Translation.tr("Clipboard history")
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
