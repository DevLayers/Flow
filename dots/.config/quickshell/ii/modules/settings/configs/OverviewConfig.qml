import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.configs.widgets

ContentPage {
    id: page
    forceWidth: false

    readonly property bool videoWallpaper: {
        const background = Config.options && Config.options.background ? Config.options.background : null;
        if (!background)
            return false;
        return background.useWallpaperEngine === true || Wallpapers.isVideoFile(background.wallpaperPath || "");
    }

    KeyboardShortcutBox {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        text: Translation.tr("Toggle the Overview screen")
        keys: ["Super"]
    }

    ContentSection {
        title: Translation.tr("Overview Configuration")
        icon: "dashboard"

        // Group 1: General Options
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Enable")
                checked: Config.options.overview.enable
                onCheckedChanged: {
                    Config.options.overview.enable = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.overview.enable
                buttonIcon: "apps"
                text: Translation.tr("Show icons")
                checked: Config.options.overview.showIcons
                onCheckedChanged: {
                    Config.options.overview.showIcons = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.overview.enable
                buttonIcon: "photo"
                text: Translation.tr("Show window previews (screencopy)")
                checked: Config.options.overview.showWindowPreviews
                onCheckedChanged: {
                    Config.options.overview.showWindowPreviews = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.overview.enable && Config.options.overview.showIcons
                buttonIcon: "vertical_align_center"
                text: Translation.tr("Center icons")
                checked: Config.options.overview.centerIcons
                onCheckedChanged: {
                    Config.options.overview.centerIcons = checked;
                }
            }

        }

        Item { Layout.preferredHeight: 16 }

        // Group 2: Behaviors
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                enabled: Config.options.overview.enable
                buttonIcon: "tune"
                text: Translation.tr("Manual Scale (Override Auto-Scale)")
                checked: Config.options.overview.enableManualScale
                onCheckedChanged: {
                    Config.options.overview.enableManualScale = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.overview.enable && !Config.options.overview.enableManualScale
                icon: "zoom_in_map"
                text: Translation.tr("Auto-Scale Factor (%)")
                value: (Config.options.overview.autoScaleFactor ?? 1.0) * 100
                from: 50
                to: 150
                stepSize: 5
                onValueChanged: {
                    Config.options.overview.autoScaleFactor = value / 100;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.overview.enable && Config.options.overview.enableManualScale
                icon: "aspect_ratio"
                text: Translation.tr("Custom Scale (%)")
                value: Config.options.overview.scale * 100
                from: 10
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.overview.scale = value / 100;
                }
            }

            ContentSubsection {
                title: Translation.tr("Animation Style")
                icon: "animation"
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.rounding.verysmall

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        currentValue: Config.options.overview.animationStyle ?? "bounce"
                        onSelected: newValue => {
                            Config.options.overview.animationStyle = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Slide + Bounce"), icon: "animation", value: "bounce" },
                            { displayName: Translation.tr("Smooth Slide"), icon: "swipe", value: "smooth" },
                            { displayName: Translation.tr("Zoom In"), icon: "zoom_in", value: "zoom" }
                        ]
                    }

                    OverviewPreviewButton {
                        Layout.alignment: Qt.AlignVCenter
                        enabled: Config.options.overview.enable
                        tooltipText: Translation.tr("Open the Overview to preview the animation in real time")
                    }
                }
            }

            ConfigSwitch {
                enabled: Config.options.overview.enable
                buttonIcon: "auto_awesome"
                text: Translation.tr("Cascade Workspace Entrance")
                checked: Config.options.overview.enableCascadeAnimation ?? true
                onCheckedChanged: {
                    Config.options.overview.enableCascadeAnimation = checked;
                }
            }

        }
    }

    ContentSection {
        title: Translation.tr("Classic Style")
        icon: "grid_view"

        ColumnLayout {
            id: classicLayout
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            GridLayout {
                id: classicControls
                Layout.fillWidth: true
                columns: width >= Appearance.font.pixelSize.hugeass * 32 ? 2 : 1
                columnSpacing: Appearance.rounding.verysmall
                rowSpacing: Appearance.rounding.verysmall

                ConfigSpinBox {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "view_agenda"
                    text: Translation.tr("Rows")
                    value: Config.options.overview.rows
                    from: 1
                    to: 10
                    stepSize: 1
                    topLeftRadius: Appearance.rounding.large
                    topRightRadius: Appearance.rounding.verysmall
                    bottomLeftRadius: Appearance.rounding.verysmall
                    bottomRightRadius: Appearance.rounding.verysmall
                    onValueChanged: {
                        Config.options.overview.rows = value;
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "view_column"
                    text: Translation.tr("Columns")
                    value: Config.options.overview.columns
                    from: 1
                    to: 10
                    stepSize: 1
                    topLeftRadius: Appearance.rounding.verysmall
                    topRightRadius: Appearance.rounding.large
                    bottomLeftRadius: Appearance.rounding.verysmall
                    bottomRightRadius: Appearance.rounding.verysmall
                    onValueChanged: {
                        Config.options.overview.columns = value;
                    }
                }

                ContentSubsection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("Horizontal direction")
                    icon: "swap_horiz"
                    topLeftRadius: Appearance.rounding.verysmall
                    topRightRadius: Appearance.rounding.verysmall
                    bottomLeftRadius: Appearance.rounding.large
                    bottomRightRadius: Appearance.rounding.verysmall

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        currentValue: Config.options.overview.orderRightLeft
                        onSelected: newValue => {
                            Config.options.overview.orderRightLeft = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Left to right"), icon: "arrow_forward", value: false },
                            { displayName: Translation.tr("Right to left"), icon: "arrow_back", value: true }
                        ]
                    }
                }

                ContentSubsection {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("Vertical direction")
                    icon: "swap_vert"
                    topLeftRadius: Appearance.rounding.verysmall
                    topRightRadius: Appearance.rounding.verysmall
                    bottomLeftRadius: Appearance.rounding.verysmall
                    bottomRightRadius: Appearance.rounding.large

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        currentValue: Config.options.overview.orderBottomUp
                        onSelected: newValue => {
                            Config.options.overview.orderBottomUp = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Top-down"), icon: "arrow_downward", value: false },
                            { displayName: Translation.tr("Bottom-up"), icon: "arrow_upward", value: true }
                        ]
                    }
                }
            }

            OverviewGridPreview {
                id: overviewPreview
                Layout.fillWidth: true
                rows: Config.options.overview.rows
                columns: Config.options.overview.columns
                rightToLeft: Config.options.overview.orderRightLeft
                bottomUp: Config.options.overview.orderBottomUp
                autoScaleFactor: Config.options.overview.autoScaleFactor ?? 1.0
            }
        }
    }

    ContentSection {
        title: Translation.tr("Zoom animation")
        icon: "zoom_in_map"

        NoticeBox {
            Layout.fillWidth: true
            visible: page.videoWallpaper
            materialIcon: "movie"
            text: Translation.tr("Video wallpaper is active: only the default zoom style is available.")
        }

        ConfigSwitch {
            buttonIcon: "zoom_in_map"
            text: Translation.tr("Zoom animation when overview/cheatsheet is open (Experimental)")
            checked: Config.options.background.zoomOutEnabled
            onCheckedChanged: Config.options.background.zoomOutEnabled = checked
            StyledToolTip {
                text: Translation.tr("Scale windows with the wallpaper when Overview or the Cheat Sheet opens.")
            }
        }

        ContentSubsection {
            visible: Config.options.background.zoomOutEnabled || page.videoWallpaper
            title: Translation.tr("Zoom background style")
            icon: "style"
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.verysmall

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    currentValue: Config.options.background.zoomOutStyle
                    onSelected: newValue => Config.options.background.zoomOutStyle = newValue
                    options: [
                        { displayName: Translation.tr("Gnome Like"), icon: "blur_on", enabled: !page.videoWallpaper, value: 0 },
                        { displayName: Translation.tr("Default"), icon: "grid_view", value: 1 },
                        { displayName: Translation.tr("Zoom In"), icon: "zoom_in", enabled: !page.videoWallpaper, value: 2 }
                    ]
                }

                OverviewPreviewButton {
                    Layout.alignment: Qt.AlignVCenter
                    enabled: Config.options.background.zoomOutEnabled && (!page.videoWallpaper || Config.options.background.zoomOutStyle === 1)
                    tooltipText: !Config.options.background.zoomOutEnabled
                        ? Translation.tr("Enable Zoom animation to preview this style.")
                        : Translation.tr("Open the Overview to preview the selected zoom style")
                }
            }
        }

        ConfigSwitch {
            visible: (Config.options.background.zoomOutEnabled && Config.options.background.zoomOutStyle === 0) || page.videoWallpaper
            enabled: !page.videoWallpaper
            buttonIcon: "open_with"
            text: Translation.tr("Scale windows with wallpaper (Experimental)")
            checked: Config.options.background.windowZoomOnOverview
            onCheckedChanged: Config.options.background.windowZoomOnOverview = checked
            StyledToolTip {
                text: Translation.tr("Show scaled window previews zooming out with the wallpaper when the overview opens.")
            }
        }

        ConfigSwitch {
            visible: (Config.options.background.zoomOutEnabled && Config.options.background.zoomOutStyle === 0 && Config.options.background.windowZoomOnOverview) || page.videoWallpaper
            enabled: !page.videoWallpaper
            buttonIcon: "videocam"
            text: Translation.tr("Keep screencopy live (no freeze)")
            checked: Config.options.background.windowZoomLiveCapture
            onCheckedChanged: Config.options.background.windowZoomLiveCapture = checked
            StyledToolTip {
                text: Translation.tr("Keep window previews live instead of freezing them when the overview opens.")
            }
        }
    }

    ContentSection {
        icon: "link"
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "workspaces"
                label: Translation.tr("Workspaces")
            }
        }
    }
}
