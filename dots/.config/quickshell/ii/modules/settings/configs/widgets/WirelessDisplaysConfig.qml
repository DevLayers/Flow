import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false

    signal goBack()

    Component.onCompleted: SunshineService.refresh()

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

        ColumnLayout {
            spacing: 1

            StyledText {
                text: Translation.tr("Remote Streaming")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }

            StyledText {
                text: Translation.tr("Sunshine host for Moonlight clients")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }

    ContentSection {
        icon: "info"
        title: Translation.tr("Sunshine & Moonlight")

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Sunshine hosts a low-latency desktop stream from this computer. Open Moonlight on your TV, tablet, phone, or another computer and connect to this host from the client device.")
        }

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Moonlight normally discovers Sunshine automatically on the same local network. If the host does not appear, add the LAN address shown below manually in Moonlight.")
        }
    }

    ContentSection {
        icon: "cast_connected"
        title: Translation.tr("Sunshine Host")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusLayout.implicitHeight + 28
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: statusLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: !SunshineService.installed ? "warning" : (SunshineService.running ? "cast_connected" : "cast")
                    shape: MaterialShape.Shape.Cookie9Sided
                    iconSize: Appearance.font.pixelSize.large
                    padding: 10
                    fill: SunshineService.running ? 1 : 0
                    color: SunshineService.running ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
                    colSymbol: SunshineService.running ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (!SunshineService.installed)
                                return Translation.tr("Sunshine not detected");
                            if (SunshineService.running)
                                return Translation.tr("Sunshine is ready");
                            return Translation.tr("Sunshine is stopped");
                        }
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.body
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: SunshineService.serviceAvailable
                            ? SunshineService.serviceUnit
                            : Translation.tr("Install the native Sunshine package to expose its user service.")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideMiddle
                    }
                }

                RippleButton {
                    buttonText: Translation.tr("Refresh")
                    buttonRadius: Appearance.rounding.small
                    enabled: !SunshineService.refreshing && !SunshineService.actionRunning
                    onClicked: SunshineService.refresh()
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Run Sunshine host")
            checked: SunshineService.running
            enabled: SunshineService.serviceAvailable && !SunshineService.refreshing && !SunshineService.actionRunning
            onCheckedChanged: {
                if (SunshineService.refreshing || SunshineService.actionRunning || checked === SunshineService.running)
                    return;
                SunshineService.setRunning(checked);
            }
            StyledToolTip {
                text: Translation.tr("Starts or stops the Sunshine user service for the current session.")
            }
        }

        ConfigSwitch {
            buttonIcon: "login"
            text: Translation.tr("Start Sunshine on login")
            checked: SunshineService.enabledOnLogin
            enabled: SunshineService.serviceAvailable && !SunshineService.refreshing && !SunshineService.actionRunning
            onCheckedChanged: {
                if (SunshineService.refreshing || SunshineService.actionRunning || checked === SunshineService.enabledOnLogin)
                    return;
                SunshineService.setEnabledOnLogin(checked);
            }
            StyledToolTip {
                text: Translation.tr("Enables or disables the Sunshine systemd user service at login.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "restart_alt"
                mainText: Translation.tr("Restart")
                enabled: SunshineService.serviceAvailable && SunshineService.running && !SunshineService.actionRunning
                onClicked: SunshineService.restart()
            }

            RippleButtonWithIcon {
                materialIcon: "open_in_new"
                mainText: Translation.tr("Open Sunshine Web UI")
                enabled: SunshineService.installed
                onClicked: SunshineService.openWebUi()
            }
        }

        NoticeBox {
            visible: SunshineService.lastError.length > 0
            Layout.fillWidth: true
            text: SunshineService.lastError
        }
    }

    ContentSection {
        icon: "router"
        title: Translation.tr("Connect a Moonlight Device")

        HelperCodeBox {
            Layout.fillWidth: true
            icon: "lan"
            title: Translation.tr("Host address")
            text: Translation.tr("Use this address in Moonlight only if automatic discovery does not find this computer.")
            codeSnippet: SunshineService.hostAddress.length > 0
                ? SunshineService.hostAddress
                : Translation.tr("No LAN address detected")
            snippetWrapMode: Text.Wrap
        }

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Pairing flow: open Moonlight on the client, select this computer (or add the host address), then open the Sunshine Web UI and enter the PIN shown by Moonlight in Sunshine's PIN page.")
        }

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("The Sunshine Web UI uses HTTPS on port 47990 by default and may show a browser warning because its local certificate is self-signed.")
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "open_in_new"
            mainText: Translation.tr("Open Sunshine Web UI")
            centerContent: true
            enabled: SunshineService.installed
            onClicked: SunshineService.openWebUi()
        }
    }
}
