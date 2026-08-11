import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Item {
    id: backgroundRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        readonly property bool videoWallpaper: {
            const background = Config.options && Config.options.background ? Config.options.background : null;
            if (!background) return false;
            return background.useWallpaperEngine === true || Wallpapers.isVideoFile(background.wallpaperPath || "");
        }

        ContentSection {
            title: Translation.tr("Parallax Engine")
            icon: "sync_alt"

            NoticeBox {
                Layout.fillWidth: true
                visible: page.videoWallpaper
                materialIcon: "movie"
                text: Translation.tr("Video wallpaper active: window blur and parallax are disabled automatically; only the Default zoom style is available.")
            }

            ConfigSwitch {
                buttonIcon: "counter_1"
                text: Translation.tr("Depends on workspace")
                enabled: !page.videoWallpaper
                checked: Config.options.background.parallax.enableWorkspace
                configPage: Qt.resolvedUrl("widgets/ParallaxConfig.qml")
                onCheckedChanged: {
                    Config.options.background.parallax.enableWorkspace = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Click button text to configure parallax movement directions, sidebars, and intensity.")
                }
            }
        }

        ContentSection {
            title: Translation.tr("Overview Animation & Blur")
            icon: "grain"

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Blur wallpaper when window open (Experimental)")
                enabled: !page.videoWallpaper
                checked: Config.options.background.blurWhenWindowsOpen
                onCheckedChanged: {
                    Config.options.background.blurWhenWindowsOpen = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Experimental - Blur the wallpaper and widgets when a window is open on the current workspace.")
                }
            }

            ConfigSlider {
                buttonIcon: "lens_blur"
                text: Translation.tr("Blur intensity when a window is open")
                enabled: !page.videoWallpaper
                visible: Config.options.background.blurWhenWindowsOpen
                usePercentTooltip: true
                from: 0
                to: 100
                stepSize: 1
                value: Config.options.background.blurWhenWindowsOpenRadius ?? 80
                onValueChanged: {
                    Config.options.background.blurWhenWindowsOpenRadius = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "zoom_in_map"
                text: Translation.tr("Zoom animation when overview/cheatsheet is open (Experimental)")
                checked: Config.options.background.zoomOutEnabled
                onCheckedChanged: {
                    Config.options.background.zoomOutEnabled = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Experimental - Scale windows with wallpaper when Overview/Cheatsheet is opened, this is a work in progress, expect bugs and a lags on low end hardware.")
                }
            }

            ContentSubsection {
                visible: Config.options.background.zoomOutEnabled || page.videoWallpaper
                title: Translation.tr("Zoom background style")
                icon: "style"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.background.zoomOutStyle
                    onSelected: newValue => {
                        Config.options.background.zoomOutStyle = newValue;
                    }
                    options: [
                        {
                            "displayName": Translation.tr("Gnome Like"),
                            "icon": "blur_on",
                            "enabled": !page.videoWallpaper,
                            "value": 0
                        },
                        {
                            "displayName": Translation.tr("Default"),
                            "icon": "grid_view",
                            "value": 1
                        },
                        {
                            "displayName": Translation.tr("Zoom In"),
                            "icon": "zoom_in",
                            "enabled": !page.videoWallpaper,
                            "value": 2
                        }
                    ]
                }
            }

            ConfigSwitch {
                visible: (Config.options.background.zoomOutEnabled && Config.options.background.zoomOutStyle === 0) || page.videoWallpaper
                enabled: !page.videoWallpaper
                buttonIcon: "open_with"
                text: Translation.tr("Scale windows with wallpaper (Experimental)")
                checked: Config.options.background.windowZoomOnOverview
                onCheckedChanged: {
                    Config.options.background.windowZoomOnOverview = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Shows scaled ScreencopyView of windows zooming out with the wallpaper when the overview opens.\nWindows on the active workspace follow the wallpaper zoom animation.\nWorkspace switching slides the window previews alongside the workspace animation.")
                }
            }

            ConfigSwitch {
                visible: (Config.options.background.zoomOutEnabled && Config.options.background.zoomOutStyle === 0 && Config.options.background.windowZoomOnOverview) || page.videoWallpaper
                enabled: !page.videoWallpaper
                buttonIcon: "videocam"
                text: Translation.tr("Keep screencopy live (no freeze)")
                checked: Config.options.background.windowZoomLiveCapture
                onCheckedChanged: {
                    Config.options.background.windowZoomLiveCapture = checked;
                }

                StyledToolTip {
                    text: Translation.tr("When enabled, window previews stay live instead of freezing on overview open.\nDisable for better performance (freezes capture on open).")
                }
            }
        }

        KeyboardShortcutBox {
            Layout.fillWidth: true
            text: Translation.tr("Toggle Media Mode")
            keys: ["Super", "Z"]
        }

        ContentSection {
            title: Translation.tr("Media Mode Background")
            icon: "music_note"

            NoticeBox {
                Layout.fillWidth: true
                isFirst: true
                text: Translation.tr("These settings apply exclusively to the full-screen Media Mode background overlay.")
            }

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Media mode background overlay")
                checked: Config.options.background.mediaMode.showLyrics ?? true
                configPage: Qt.resolvedUrl("widgets/MediaModeBackgroundConfig.qml")
                onCheckedChanged: {
                    Config.options.background.mediaMode.showLyrics = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Click button text to configure lyrics, visualizers, album art opacity, and music video settings.")
                }
            }
        }

        ShortcutBox {
            Layout.fillWidth: true
            value: Translation.tr("Desktop Clock Widget settings")
            targetPageId: "widgets"
            targetSectionTitle: Translation.tr("Widget Manager")
        }

        ContentSection {
            icon: "link"
            title: Translation.tr("Related settings")

            Flow {
                Layout.fillWidth: true
                spacing: 8

                RelatedChip {
                    pageId: "windows"
                    label: Translation.tr("Window blur")
                    sectionHighlight: Translation.tr("Transparency & Blur")
                }

                RelatedChip {
                    pageId: "lockScreen"
                    label: Translation.tr("Lock screen blur")
                    sectionHighlight: Translation.tr("Blur style")
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
