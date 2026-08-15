import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false

    signal goBack()

    RowLayout {
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
            text: Translation.tr("Wireless Displays & Cast")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "info"
        title: Translation.tr("Information & Requirements")

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Display & Cast lets you project your desktop to external monitors (Primary only, Duplicate, Extend, External only) or stream wirelessly to smart TVs and receivers using Miracast and Chromecast.")
        }

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Important: Avoid using the Flatpak version of GNOME Network Displays. The Flatpak runtime lacks essential H.264 video encoding codecs on Fedora, which causes black screens on TVs. Always use the native system package: sudo dnf install gnome-network-displays.")
        }

        KeyboardShortcutBox {
            Layout.fillWidth: true
            text: Translation.tr("Open Display & Cast quick popup")
            keys: ["Super", "Shift", "P"]
        }
    }

    ContentSection {
        icon: "network_check"
        title: Translation.tr("System Capabilities & Diagnostics")

        NetworkDisplayStatusCard {
            Layout.fillWidth: true
        }

        HelperCodeBox {
            visible: !NetworkDisplayService.bridgeAvailable
            Layout.fillWidth: true
            icon: "terminal"
            title: Translation.tr("Compile Rust Network Display Bridge")
            text: Translation.tr("To compile and install the native D-Bus casting bridge helper, run this command in your terminal (requires Rust toolchain and cargo):")
            codeSnippet: "cd " + Directories.scriptPath + "/networkDisplays/network_display_bridge_src && cargo build --release && cp target/release/network_display_bridge ../network_display_bridge"
            snippetWrapMode: Text.Wrap
        }

        HelperCodeBox {
            visible: !NetworkDisplayService.backendInstalled
            Layout.fillWidth: true
            icon: "download"
            title: Translation.tr("Install GNOME Network Displays (Native Package)")
            text: Translation.tr("GNOME Network Displays is required for discovery and stream orchestration. Install the native package via DNF:")
            codeSnippet: "sudo dnf install -y gnome-network-displays"
            snippetWrapMode: Text.Wrap
        }
    }

    ContentSection {
        icon: "settings_input_antenna"
        title: Translation.tr("Protocols & Behavior")

        ConfigSwitch {
            buttonIcon: "wifi"
            text: Translation.tr("Miracast (Wi-Fi Direct P2P)")
            checked: (Config.options.displayCast && Config.options.displayCast.showMiracastP2p !== undefined) ? Config.options.displayCast.showMiracastP2p : true
            onCheckedChanged: {
                if (Config.ready && Config.options.displayCast) {
                    Config.options.displayCast.showMiracastP2p = checked;
                }
            }
            StyledToolTip {
                text: Translation.tr("Direct peer-to-peer Wi-Fi connection to TV/receivers without a shared router.")
            }
        }

        ConfigSwitch {
            buttonIcon: "router"
            text: Translation.tr("Miracast over Infrastructure (MICE)")
            checked: (Config.options.displayCast && Config.options.displayCast.showMiracastMice !== undefined) ? Config.options.displayCast.showMiracastMice : true
            onCheckedChanged: {
                if (Config.ready && Config.options.displayCast) {
                    Config.options.displayCast.showMiracastMice = checked;
                }
            }
            StyledToolTip {
                text: Translation.tr("Connects to Miracast displays discovered over the existing local Wi-Fi / LAN.")
            }
        }

        ConfigSwitch {
            buttonIcon: "cast"
            text: Translation.tr("Google Cast / Chromecast")
            checked: (Config.options.displayCast && Config.options.displayCast.showChromecast !== undefined) ? Config.options.displayCast.showChromecast : true
            onCheckedChanged: {
                if (Config.ready && Config.options.displayCast) {
                    Config.options.displayCast.showChromecast = checked;
                }
            }
            StyledToolTip {
                text: Translation.tr("Casting to Android TVs, Google TV, Chromecast dongles, and Nest displays.")
            }
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Stop backend when idle")
            checked: (Config.options.displayCast && Config.options.displayCast.stopBackendWhenIdle !== undefined) ? Config.options.displayCast.stopBackendWhenIdle : true
            onCheckedChanged: {
                if (Config.ready && Config.options.displayCast) {
                    Config.options.displayCast.stopBackendWhenIdle = checked;
                }
            }
            StyledToolTip {
                text: Translation.tr("Automatically stops background discovery and streaming processes when the popup closes.")
            }
        }

        ConfigSwitch {
            buttonIcon: "close_fullscreen"
            text: Translation.tr("Close popup after changing projection mode")
            checked: (Config.options.displayCast && Config.options.displayCast.closeAfterProjectionChange !== undefined) ? Config.options.displayCast.closeAfterProjectionChange : true
            onCheckedChanged: {
                if (Config.ready && Config.options.displayCast) {
                    Config.options.displayCast.closeAfterProjectionChange = checked;
                }
            }
            StyledToolTip {
                text: Translation.tr("Closes the Display & Cast popup immediately after selecting a projection mode.")
            }
        }
    }
}
