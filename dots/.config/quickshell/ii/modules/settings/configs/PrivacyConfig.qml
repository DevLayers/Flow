import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root

    forceWidth: false

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

        NoticeBox {
            Layout.fillWidth: true
            isFirst: true
            text: Translation.tr("Supported VPN backends: NetworkManager profiles (OpenVPN and WireGuard), NordVPN CLI, and Proton VPN CLI when installed. Credentials stay in the provider or system keyring; they are never saved to config.json.")
        }


        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Enable VPN Integration")
            checked: Config.options.vpn.enabled
            onCheckedChanged: {
                Config.options.vpn.enabled = checked;
            }
            StyledToolTip {
                text: Translation.tr("Toggles VPN management service and quick panel integration across the shell.")
            }
        }
        ConfigSwitch {
            buttonIcon: "link_off"
            text: Translation.tr("Disconnect VPN when integration is disabled")
            checked: Config.options.vpn.disconnectOnDisable
            onCheckedChanged: Config.options.vpn.disconnectOnDisable = checked
            StyledToolTip { text: Translation.tr("Disconnects the active provider/profile when VPN integration is turned off. NetworkManager itself remains running.") }
        }


        ConfigSwitch {
            buttonIcon: "autorenew"
            text: Translation.tr("Connect VPN automatically")
            checked: Config.options.vpn.autoConnect
            onCheckedChanged: Config.options.vpn.autoConnect = checked
            StyledToolTip {
                text: Translation.tr("Automatically connects to default profile upon shell startup or network availability.")
            }
        }

        ContentSubsectionLabel { text: Translation.tr("Provider & Profiles") }

        ConfigSelectionArray {
            Layout.fillWidth: true
            options: [
                { displayName: Translation.tr("NetworkManager"), icon: "lan", value: "networkmanager" },
                { displayName: Translation.tr("NordVPN"), icon: "vpn_key", value: "nordvpn", enabled: VpnService.nordvpnAvailable },
                { displayName: Translation.tr("Proton VPN"), icon: "vpn_key", value: "protonvpn", enabled: VpnService.protonvpnAvailable }
            ]
            currentValue: Config.options.vpn.defaultProvider
            onSelected: value => Config.options.vpn.defaultProvider = value
        }

        ConfigTextField {
            icon: "bookmark"
            text: Translation.tr("Default VPN profile")
            placeholderText: Translation.tr("Choose a profile in the VPN dialog")
            inputText: Config.options.vpn.defaultProfile
            textField.onTextChanged: Config.options.vpn.defaultProfile = textField.text
        }

        ConfigTextField {
            icon: "location_on"
            text: Translation.tr("Default VPN location")
            placeholderText: Translation.tr("Optional provider location or server")
            inputText: Config.options.vpn.defaultLocation
            textField.onTextChanged: Config.options.vpn.defaultLocation = textField.text
        }

        ContentSubsectionLabel { text: Translation.tr("Advanced Security") }

        ConfigSwitch {
            buttonIcon: "security"
            text: VpnService.killSwitchSupported ? Translation.tr("VPN kill switch") : Translation.tr("VPN kill switch (unsupported by backend)")
            checked: Config.options.vpn.killSwitch
            enabled: VpnService.killSwitchSupported
            onCheckedChanged: Config.options.vpn.killSwitch = checked
        }

        ConfigSwitch {
            buttonIcon: "lan"
            text: VpnService.blockLanSupported ? Translation.tr("Block local network while VPN is active") : Translation.tr("Block local network (unsupported by backend)")
            checked: Config.options.vpn.blockLan
            enabled: VpnService.blockLanSupported
            onCheckedChanged: Config.options.vpn.blockLan = checked
        }

        ConfigSwitch {
            buttonIcon: "troubleshoot"
            text: Translation.tr("Enable VPN diagnostics")
            checked: Config.options.vpn.enableDiagnostics
            onCheckedChanged: Config.options.vpn.enableDiagnostics = checked
        }

        TipBox {
            Layout.fillWidth: true
            materialIcon: "help"
            text: Translation.tr("VPN Setup: Make sure NetworkManager VPN plugins (nmcli) or WireGuard interfaces are installed. Click/Right-click the Quick Toggle to connect or select profiles.")
        }
    }

    ContentSection {
        icon: "hub"
        title: Translation.tr("Tailscale Mesh Settings")

        NoticeBox {
            Layout.fillWidth: true
            isFirst: true
            text: Translation.tr("Tailscale builds a secure peer-to-peer mesh VPN between your phone, laptop, and servers using WireGuard.")
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Enable Tailscale Integration")
            checked: Config.options.tailscale.enabled
            onCheckedChanged: {
                Config.options.tailscale.enabled = checked;
            }
            StyledToolTip {
                text: Translation.tr("Enables Tailscale daemon monitoring and dashboard controls.")
            }
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
