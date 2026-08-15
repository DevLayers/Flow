import QtQuick
import QtQuick.Layouts
import Quickshell
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
                text: Translation.tr("Manage this Sunshine host for Moonlight")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }

    ContentSection {
        icon: "cast_connected"
        title: Translation.tr("Host")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: hostLayout.implicitHeight + 32
            radius: Appearance.rounding.large
            color: SunshineService.running
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colLayer2

            RowLayout {
                id: hostLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: !SunshineService.installed ? "warning" : (SunshineService.running ? "cast_connected" : "cast")
                    shape: MaterialShape.Shape.Cookie9Sided
                    iconSize: Appearance.font.pixelSize.huge
                    padding: 12
                    fill: SunshineService.running ? 1 : 0
                    color: SunshineService.running
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSecondaryContainer
                    colSymbol: SunshineService.running
                        ? Appearance.colors.colOnPrimary
                        : Appearance.colors.colOnSecondaryContainer
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (!SunshineService.installed)
                                return Translation.tr("Sunshine is not installed");
                            if (SunshineService.running)
                                return Translation.tr("Ready to stream");
                            return Translation.tr("Sunshine is stopped");
                        }
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        color: SunshineService.running
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const host = SunshineService.hostName.length > 0 ? SunshineService.hostName : Translation.tr("This computer");
                            const address = SunshineService.hostAddress.length > 0 ? SunshineService.hostAddress : Translation.tr("No LAN address detected");
                            return `${host}  ·  ${address}`;
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: SunshineService.running
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                        opacity: 0.8
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: SunshineService.installed
                        text: Translation.tr("%1 paired device(s)").arg(SunshineService.pairedClientCount)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: SunshineService.running
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                        opacity: 0.7
                    }
                }

                RippleButton {
                    visible: SunshineService.serviceAvailable
                    Layout.alignment: Qt.AlignVCenter
                    buttonText: SunshineService.running ? Translation.tr("Stop") : Translation.tr("Start")
                    buttonRadius: Appearance.rounding.full
                    enabled: !SunshineService.actionRunning && !SunshineService.refreshing
                    colBackground: SunshineService.running
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSecondaryContainer
                    colBackgroundHover: SunshineService.running
                        ? Appearance.colors.colPrimaryHover
                        : Appearance.colors.colSecondaryContainerHover
                    onClicked: SunshineService.setRunning(!SunshineService.running)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "open_in_new"
                mainText: Translation.tr("Sunshine Web UI")
                centerContent: true
                enabled: SunshineService.installed
                onClicked: SunshineService.openWebUi()
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "refresh"
                mainText: Translation.tr("Refresh")
                centerContent: true
                enabled: !SunshineService.refreshing && !SunshineService.actionRunning
                onClicked: SunshineService.refresh()
            }
        }

        NoticeBox {
            visible: SunshineService.lastError.length > 0
            Layout.fillWidth: true
            text: SunshineService.lastError
        }
    }

    ContentSection {
        icon: "add_to_queue"
        title: Translation.tr("Connect a device")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Pairing starts from Moonlight. Follow these three steps once for each new device.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        number: "1",
                        icon: "devices",
                        title: Translation.tr("Open Moonlight"),
                        description: Translation.tr("On the TV, tablet, phone, or another computer")
                    },
                    {
                        number: "2",
                        icon: "lan",
                        title: Translation.tr("Select this PC"),
                        description: SunshineService.hostAddress.length > 0
                            ? SunshineService.hostAddress
                            : Translation.tr("Use automatic discovery")
                    },
                    {
                        number: "3",
                        icon: "pin",
                        title: Translation.tr("Approve the PIN"),
                        description: Translation.tr("Open Sunshine Web UI and enter the PIN shown by Moonlight")
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: stepLayout.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: stepLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSecondaryContainer

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.number
                                    font.weight: Font.Bold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 19
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.body
                            color: Appearance.colors.colOnLayer2
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.description
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "pin"
            mainText: Translation.tr("Open Sunshine to approve PIN")
            centerContent: true
            enabled: SunshineService.installed
            onClicked: SunshineService.openWebUi()
        }

        ContentSubsection {
            title: Translation.tr("Paired devices")
            icon: "devices_other"

            Rectangle {
                visible: SunshineService.pairedClients.length === 0
                Layout.fillWidth: true
                implicitHeight: emptyClientsLayout.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: emptyClientsLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    MaterialSymbol {
                        text: "devices_off"
                        iconSize: 22
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("No paired Moonlight devices found yet")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Repeater {
                model: SunshineService.pairedClients

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: clientLayout.implicitHeight + 20
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: clientLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        MaterialShapeWrappedMaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "devices"
                            shape: MaterialShape.Shape.Circle
                            iconSize: 19
                            padding: 8
                            fill: modelData.enabled ? 1 : 0
                            color: modelData.enabled
                                ? Appearance.colors.colSecondaryContainer
                                : Appearance.colors.colLayer1
                            colSymbol: modelData.enabled
                                ? Appearance.colors.colOnSecondaryContainer
                                : Appearance.colors.colSubtext
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.body
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.enabled ? Translation.tr("Paired and allowed") : Translation.tr("Paired · disabled in Sunshine")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledText {
                            text: modelData.enabled ? Translation.tr("Ready") : Translation.tr("Disabled")
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: modelData.enabled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }
                }
            }

            StyledText {
                visible: SunshineService.pairedClients.length > 0
                Layout.fillWidth: true
                text: Translation.tr("Pairing changes and device removal remain in Sunshine Web UI so ii never stores your Sunshine administrator password.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("Streaming controls")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("These controls edit Sunshine's local configuration. If the host is running, Sunshine restarts automatically to apply the change.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        ContentSubsection {
            title: Translation.tr("Remote input")
            icon: "touch_app"

            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard input")
                checked: SunshineService.keyboardEnabled
                enabled: SunshineService.installed && !SunshineService.actionRunning
                onCheckedChanged: {
                    if (checked === SunshineService.keyboardEnabled || SunshineService.actionRunning)
                        return;
                    SunshineService.setInputOption("keyboard", checked);
                }
            }

            ConfigSwitch {
                buttonIcon: "mouse"
                text: Translation.tr("Mouse input")
                checked: SunshineService.mouseEnabled
                enabled: SunshineService.installed && !SunshineService.actionRunning
                onCheckedChanged: {
                    if (checked === SunshineService.mouseEnabled || SunshineService.actionRunning)
                        return;
                    SunshineService.setInputOption("mouse", checked);
                }
            }

            ConfigSwitch {
                buttonIcon: "sports_esports"
                text: Translation.tr("Controller input")
                checked: SunshineService.controllerEnabled
                enabled: SunshineService.installed && !SunshineService.actionRunning
                onCheckedChanged: {
                    if (checked === SunshineService.controllerEnabled || SunshineService.actionRunning)
                        return;
                    SunshineService.setInputOption("controller", checked);
                }
            }

            ConfigSwitch {
                buttonIcon: "stylus"
                text: Translation.tr("Native touch & pen")
                checked: SunshineService.nativePenTouchEnabled
                enabled: SunshineService.installed && !SunshineService.actionRunning
                onCheckedChanged: {
                    if (checked === SunshineService.nativePenTouchEnabled || SunshineService.actionRunning)
                        return;
                    SunshineService.setInputOption("native_pen_touch", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Passes native touch and pen events from supported Moonlight clients to this computer.")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Video encoder")
            icon: "memory"

            ConfigSelectionArray {
                currentValue: SunshineService.encoder
                enabled: SunshineService.installed && !SunshineService.actionRunning
                onSelected: newValue => {
                    if (newValue === SunshineService.encoder || SunshineService.actionRunning)
                        return;
                    SunshineService.setEncoder(newValue);
                }
                options: [
                    {
                        displayName: Translation.tr("Automatic"),
                        icon: "auto_awesome",
                        value: "auto"
                    },
                    {
                        displayName: "NVIDIA NVENC",
                        icon: "memory",
                        value: "nvenc"
                    },
                    {
                        displayName: "Intel Quick Sync",
                        icon: "memory",
                        value: "quicksync"
                    },
                    {
                        displayName: "AMD VCE",
                        icon: "memory",
                        value: "amdvce"
                    },
                    {
                        displayName: "VA-API",
                        icon: "memory",
                        value: "vaapi"
                    },
                    {
                        displayName: "Vulkan",
                        icon: "memory",
                        value: "vulkan"
                    },
                    {
                        displayName: Translation.tr("Software"),
                        icon: "developer_board",
                        value: "software"
                    }
                ]
            }
        }
    }

    ContentSection {
        icon: "settings"
        title: Translation.tr("Host settings")

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
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "restart_alt"
                mainText: Translation.tr("Restart Sunshine")
                centerContent: true
                enabled: SunshineService.serviceAvailable && SunshineService.running && !SunshineService.actionRunning
                onClicked: SunshineService.restart()
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "open_in_new"
                mainText: Translation.tr("Advanced settings")
                centerContent: true
                enabled: SunshineService.installed
                onClicked: SunshineService.openWebUi()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: technicalLayout.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: technicalLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Service: %1").arg(SunshineService.serviceUnit)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Config: %1").arg(SunshineService.configPath)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
