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
    id: screenCaptureRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        // ── Selection ─────────────────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Selection")
            icon: "highlight_alt"

            ConfigSwitch {
                buttonIcon: "monitor"
                text: Translation.tr("Show only on focused monitor")
                checked: Config.options.regionSelector.showOnlyOnFocusedMonitor
                onCheckedChanged: {
                    Config.options.regionSelector.showOnlyOnFocusedMonitor = checked;
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Hint target regions")
            }

            // Multi-select tiles for target region hints (Windows · Layers · Content)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // 1. Windows
                RippleButton {
                    id: btnWindows
                    Layout.fillWidth: true
                    implicitHeight: 46
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.regionSelector.targetRegions.windows
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.regionSelector.targetRegions.windows = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "desktop_windows"
                            iconSize: 20
                            fill: btnWindows.active ? 1 : 0
                            color: btnWindows.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Windows")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnWindows.active
                            color: btnWindows.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnWindows.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnWindows.active ? 1 : 0
                            color: btnWindows.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Enable region snapping for Hyprland app windows")
                    }
                }

                // 2. Layers
                RippleButton {
                    id: btnLayers
                    Layout.fillWidth: true
                    implicitHeight: 46
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.regionSelector.targetRegions.layers
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.regionSelector.targetRegions.layers = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "layers"
                            iconSize: 20
                            fill: btnLayers.active ? 1 : 0
                            color: btnLayers.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Layers")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnLayers.active
                            color: btnLayers.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnLayers.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnLayers.active ? 1 : 0
                            color: btnLayers.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Enable region snapping for Wayland layer surfaces (bars, docks, popups)")
                    }
                }

                // 3. Content
                RippleButton {
                    id: btnContent
                    Layout.fillWidth: true
                    implicitHeight: 46
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.regionSelector.targetRegions.content
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.regionSelector.targetRegions.content = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "article"
                            iconSize: 20
                            fill: btnContent.active ? 1 : 0
                            color: btnContent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Content")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnContent.active
                            color: btnContent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnContent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnContent.active ? 1 : 0
                            color: btnContent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Enable region snapping for detected on-screen visual content boxes")
                    }
                }
            }
        }

        // ── Google Lens ───────────────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Google Lens")
            icon: "search"

            ContentSubsection {
                title: Translation.tr("Selection mode")
                icon: "highlight_alt"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.search.imageSearch.useCircleSelection ? "circle" : "rectangles"
                    onSelected: (newValue) => {
                        Config.options.search.imageSearch.useCircleSelection = (newValue === "circle");
                    }
                    options: [{
                        "displayName": Translation.tr("Rectangular selection"),
                        "value": "rectangles",
                        "icon": "activity_zone"
                    }, {
                        "displayName": Translation.tr("Circle to Search"),
                        "value": "circle",
                        "icon": "gesture"
                    }]
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Rectangular selection")
                visible: !Config.options.search.imageSearch.useCircleSelection
            }

            ConfigSwitch {
                visible: !Config.options.search.imageSearch.useCircleSelection
                buttonIcon: "border_inner"
                text: Translation.tr("Show aim lines")
                checked: Config.options.regionSelector.rect.showAimLines
                onCheckedChanged: {
                    Config.options.regionSelector.rect.showAimLines = checked;
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Circle selection")
                visible: Config.options.search.imageSearch.useCircleSelection
            }

            ConfigSpinBox {
                visible: Config.options.search.imageSearch.useCircleSelection
                icon: "line_weight"
                text: Translation.tr("Stroke width")
                value: Config.options.regionSelector.circle.strokeWidth
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.regionSelector.circle.strokeWidth = value;
                }
            }

            ConfigSpinBox {
                visible: Config.options.search.imageSearch.useCircleSelection
                icon: "padding"
                text: Translation.tr("Padding")
                value: Config.options.regionSelector.circle.padding
                from: 0
                to: 100
                stepSize: 1
                onValueChanged: {
                    Config.options.regionSelector.circle.padding = value;
                }
            }
        }

        // ── Editor & screenshots ──────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Editor & Screenshots")
            icon: "transform"

            ConfigSwitch {
                buttonIcon: "edit"
                text: Translation.tr("Enable built-in right click screenshot editor")
                checked: Config.options.regionSelector.annotation.enableInlineEditor
                onCheckedChanged: {
                    Config.options.regionSelector.annotation.enableInlineEditor = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable this if you want to use the built-in screenshot editor when using right click to select area, replacing swappy.")
                }
            }

            ConfigSwitch {
                buttonIcon: "photo_library"
                text: Translation.tr("Show screenshot preview overlay")
                checked: Config.options.regionSelector.enableOverlay
                onCheckedChanged: {
                    Config.options.regionSelector.enableOverlay = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Shows a Pixel-style preview overlay at the bottom-left after taking a screenshot, with quick actions to save, edit, or delete.")
                }
            }

            ConfigSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Show copy notifications")
                checked: Config.options.regionSelector.copyNotification
                onCheckedChanged: {
                    Config.options.regionSelector.copyNotification = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Shows a system notification when a screenshot is copied to the clipboard.")
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Screenshot path")
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Screenshot path")
                text: Config.options.screenSnip.savePath
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.screenSnip.savePath = text;
                }
            }
        }

        // ── Recording Subpage Entry ──────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Screen Recording")
            icon: "screen_record"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ServiceCard {
                    cardIcon: "screen_record"
                    cardHue: 345
                    cardShape: "Circle"
                    title: Translation.tr("Recording Settings")
                    description: Translation.tr("Configure recorder provider (OBS / wf-recorder), video quality, and post-recording actions.")
                    onOpenCard: subPageOverlay.open(Qt.resolvedUrl("widgets/ScreenRecordingConfig.qml"))
                }
            }
        }
    }

    // Sub-page overlay (slides in from the right)
    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
