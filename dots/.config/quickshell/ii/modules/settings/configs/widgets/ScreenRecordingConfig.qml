import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

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
                text: Translation.tr("Screen Recording")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        // ── Provider & Notifications ─────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Recorder Provider")
            icon: "videocam"

            ContentSubsection {
                title: Translation.tr("Provider")
                icon: "video_settings"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.screenRecord.service
                    onSelected: (newValue) => {
                        Config.options.screenRecord.service = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("wf-recorder"),
                        "value": "wf-recorder",
                        "icon": "radio_button_checked"
                    }, {
                        "displayName": "OBS Studio",
                        "value": "obs",
                        "icon": "videocam"
                    }]
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                visible: Config.options.screenRecord.service === "obs"
                materialIcon: "info"
                text: Translation.tr("OBS WebSocket Setup:\n1. Open OBS Studio -> Tools -> WebSocket Server Settings.\n2. Enable WebSocket server (default port: 4455).\n3. Disable Authentication (uncheck 'Enable Authentication') OR set the OBS_API_PASSWORD environment variable.\n4. When starting recording, a screen picker portal dialog will appear to select the recording source/screen.")
            }

            ConfigSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Show recording notifications")
                checked: Config.options.screenRecord.showNotifications
                onCheckedChanged: {
                    Config.options.screenRecord.showNotifications = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Shows system notifications when screen recording starts, finishes, or errors.")
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Video record path")
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Video record path")
                text: Config.options.screenRecord.savePath
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.screenRecord.savePath = text;
                }
            }
        }

        // ── Post-Recording Actions ───────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Post-Recording")
            icon: "movie_edit"

            ContentSubsection {
                title: Translation.tr("After recording")
                icon: "output"
                tooltip: Translation.tr("Choose what happens automatically once a screen recording is saved")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: {
                        if (!Config.options.screenRecord.showEditPrompt) return "nothing";
                        if (Config.options.screenRecord.openInLosslessCut) return "losslesscut";
                        return "ask_edit";
                    }
                    onSelected: (newValue) => {
                        if (newValue === "nothing") {
                            Config.options.screenRecord.showEditPrompt = false;
                            Config.options.screenRecord.openInLosslessCut = false;
                        } else if (newValue === "ask_edit") {
                            Config.options.screenRecord.showEditPrompt = true;
                            Config.options.screenRecord.openInLosslessCut = false;
                        } else if (newValue === "losslesscut") {
                            Config.options.screenRecord.showEditPrompt = true;
                            Config.options.screenRecord.openInLosslessCut = true;
                        }
                    }
                    options: [{
                        "displayName": Translation.tr("Nothing"),
                        "icon": "block",
                        "value": "nothing"
                    }, {
                        "displayName": Translation.tr("Ask to edit"),
                        "icon": "movie_edit",
                        "value": "ask_edit"
                    }, {
                        "displayName": Translation.tr("Open in LosslessCut"),
                        "icon": "open_in_new",
                        "value": "losslesscut"
                    }]
                }
            }
        }

        // ── Local recorder settings (wf-recorder) ────────────────────────────
        ContentSection {
            title: Translation.tr("Local Recorder Engine")
            icon: "tune"
            visible: Config.options.screenRecord.service === "wf-recorder"

            ConfigSwitch {
                buttonIcon: "bolt"
                text: Translation.tr("GPU Hardware Acceleration")
                checked: Config.options.screenRecord.useGpu
                onCheckedChanged: {
                    Config.options.screenRecord.useGpu = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Uses hardware-accelerated video encoding for lower CPU usage.")
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Video Codec")
            }

            StyledComboBox {
                id: recorderCodecSelector
                buttonIcon: "movie"
                textRole: "displayName"
                model: [{
                    "displayName": Translation.tr("Auto (Recommended)"),
                    "value": "auto"
                }, {
                    "displayName": "H264 (NVIDIA GPU - NVENC)",
                    "value": "h264_nvenc"
                }, {
                    "displayName": "H264 (Intel/AMD GPU - VAAPI)",
                    "value": "h264_vaapi"
                }, {
                    "displayName": "H264 (AMD GPU - AMF)",
                    "value": "h264_amf"
                }, {
                    "displayName": "H264 (CPU - Compatibility)",
                    "value": "libx264"
                }, {
                    "displayName": "HEVC (NVIDIA GPU - NVENC)",
                    "value": "hevc_nvenc"
                }, {
                    "displayName": "HEVC (Intel/AMD GPU - VAAPI)",
                    "value": "hevc_vaapi"
                }, {
                    "displayName": "HEVC (AMD GPU - AMF)",
                    "value": "hevc_amf"
                }, {
                    "displayName": "HEVC (CPU - Compatibility)",
                    "value": "libx265"
                }]
                currentIndex: {
                    const index = model.findIndex((item) => {
                        return item.value === Config.options.screenRecord.codec;
                    });
                    return index !== -1 ? index : 0;
                }
                onActivated: (index) => {
                    Config.options.screenRecord.codec = model[index].value;
                }

                StyledToolTip {
                    parent: recorderCodecSelector
                    text: Translation.tr("Auto automatically selects the best hardware encoder on your system. NVENC is for Nvidia, VA-API is for Intel/AMD, and AMF is for AMD. CPU encodes via software and uses more resources.")
                }
            }

            ConfigSlider {
                buttonIcon: "speed"
                text: Translation.tr("Bitrate (Mbps)")
                value: Config.options.screenRecord.bitrate
                from: 1
                to: 50
                stepSize: 1
                usePercentTooltip: false
                onValueChanged: {
                    Config.options.screenRecord.bitrate = value;
                }
                StyledToolTip {
                    text: Translation.tr("Higher bitrate increases video quality but uses more disk space. 6-12 Mbps is ideal for 1080p recording.")
                }
            }

            ConfigSlider {
                buttonIcon: "av_timer"
                text: Translation.tr("Target Frame Rate (FPS)")
                value: Config.options.screenRecord.framerate
                from: 15
                to: 120
                stepSize: 5
                usePercentTooltip: false
                onValueChanged: {
                    Config.options.screenRecord.framerate = value;
                }
                StyledToolTip {
                    text: Translation.tr("Target frames per second for the recording. 60 FPS is standard for smooth desktop recordings.")
                }
            }
        }
    }
}
