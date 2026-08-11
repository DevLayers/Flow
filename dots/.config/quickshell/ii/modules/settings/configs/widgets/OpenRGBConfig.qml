import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
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
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: Translation.tr("Open RGB integration")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            id: openRgbSection
            title: Translation.tr("Open RGB integration")
            icon: "palette"

            property var openRgbConfig: ({
                enable: false,
                applyOnStartup: false,
                devices: []
            })
            property var openRgbDevices: []
            property string openRgbListScript: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/openrgb-list-devices.sh`)
            property string openRgbError: ""
            property bool openRgbRefreshing: false

            function defaultOpenRgbConfig() {
                return {
                    enable: false,
                    applyOnStartup: true,
                    devices: []
                };
            }

            function refreshOpenRgbConfig() {
                const openrgb = Config.options.appearance && Config.options.appearance.openrgb ? Config.options.appearance.openrgb : null;
                openRgbConfig = Object.assign(defaultOpenRgbConfig(), openrgb || {});
                openRgbDevices = openRgbConfig.devices || [];
            }

            function updateDevice(deviceId, patch) {
                const devices = [...(openRgbDevices || [])];
                const index = devices.findIndex(device => device.id === deviceId);
                if (index === -1) {
                    devices.push(Object.assign({
                        id: deviceId,
                        name: patch.name ?? "",
                        enabled: patch.enabled ?? false
                    }, patch));
                } else {
                    devices[index] = Object.assign({}, devices[index], patch);
                }
                openRgbDevices = devices;
                openRgbConfig.devices = devices;
                Config.setNestedValue("appearance.openrgb.devices", devices);
            }

            function refreshDevices() {
                openRgbError = "";
                openRgbRefreshing = true;
                openRgbDeviceProc.command = ["bash", openRgbListScript];
                openRgbDeviceProc.running = false;
                openRgbDeviceProc.running = true;
            }

            Component.onCompleted: refreshOpenRgbConfig()

            Connections {
                target: Config
                function onReadyChanged() {
                    if (Config.ready)
                        openRgbSection.refreshOpenRgbConfig();
                }
            }

            Process {
                id: openRgbDeviceProc
                stdout: StdioCollector {
                    onStreamFinished: {
                        openRgbRefreshing = false;
                        if (text.length === 0) {
                            openRgbError = Translation.tr("OpenRGB did not return any data.");
                            return;
                        }
                        try {
                            const payload = JSON.parse(text);
                            if (!payload.ok) {
                                openRgbError = payload.error || Translation.tr("Failed to query OpenRGB devices.");
                                return;
                            }
                            const devices = payload.devices || [];
                            const existing = openRgbDevices || [];
                            const merged = devices.map(device => {
                                const match = existing.find(prev => prev.id === device.id);
                                return {
                                    id: device.id,
                                    name: device.name,
                                    enabled: match ? match.enabled : false
                                };
                            });
                            Config.options.appearance.openrgb.devices = merged;
                            openRgbSection.refreshOpenRgbConfig();
                        } catch (e) {
                            openRgbError = Translation.tr("Failed to parse OpenRGB response.");
                        }
                    }
                }
                stderr: StdioCollector {
                    onStreamFinished: {
                        openRgbRefreshing = false;
                        const trimmed = text.trim();
                        if (trimmed.length > 0) {
                            openRgbError = trimmed;
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                id: openRgbRefreshButton
                useDynamicRadius: true
                Layout.fillWidth: true
                materialIcon: "refresh"
                mainText: openRgbSection.openRgbRefreshing ? Translation.tr("Refreshing...") : Translation.tr("Refresh devices")
                enabled: !openRgbSection.openRgbRefreshing
                onClicked: {
                    openRgbSection.refreshDevices();
                }
            }

            NoticeBox {
                id: openRgbErrorBox
                Layout.fillWidth: true
                visible: openRgbSection.openRgbError.length > 0
                materialIcon: "error"
                text: openRgbSection.openRgbError
            }

            ContentSubsectionLabel {
                text: Translation.tr("Detected Devices")
                visible: openRgbSection.openRgbRefreshing || (openRgbSection.openRgbDevices || []).length > 0
            }

            StyledText {
                visible: openRgbSection.openRgbRefreshing
                text: Translation.tr("Querying OpenRGB server...")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
                Layout.margins: 8
            }

            Repeater {
                model: openRgbSection.openRgbDevices || []
                ConfigSwitch {
                    required property var modelData
                    required property int index
                    buttonIcon: "memory"
                    text: modelData.name && modelData.name.length > 0 ? modelData.name : Translation.tr("Device %1").arg(modelData.id)
                    checked: modelData.enabled === true
                    onCheckedChanged: {
                        openRgbSection.updateDevice(modelData.id, {
                            enabled: checked,
                            name: modelData.name
                        });
                    }
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                visible: (openRgbSection.openRgbDevices || []).length === 0 && !openRgbSection.openRgbRefreshing && openRgbSection.openRgbError.length === 0
                materialIcon: "warning"
                text: Translation.tr("No OpenRGB devices detected. Ensure the server is running.")
            }

            ContentSubsectionLabel {
                text: Translation.tr("Integration Settings")
            }

            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Fade duration (ms)")
                value: Config.options.appearance.openrgb.fadeDuration * 1000
                from: 0
                to: 10000
                stepSize: 100
                onValueChanged: {
                    Config.options.appearance.openrgb.fadeDuration = value / 1000;
                }
            }

            ConfigSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Apply on startup")
                checked: Config.options.appearance.openrgb.applyOnStartup
                onCheckedChanged: {
                    Config.options.appearance.openrgb.applyOnStartup = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Runs the OpenRGB apply script after startup once config is loaded.")
                }
            }
        }
    }
}
