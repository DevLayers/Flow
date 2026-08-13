import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentSection {
    title: Translation.tr("Wallpaper Variants")
    icon: "collections"

    ContentSubsectionLabel {
        text: Translation.tr("Lockscreen wallpaper")
    }

    ConfigSwitch {
        buttonIcon: "lock"
        text: Translation.tr("Separate Lockscreen Wallpaper")
        checked: Config.options.background.useSeparateLockscreenWallpaper
        onCheckedChanged: {
            Config.options.background.useSeparateLockscreenWallpaper = checked;
            if (checked && !Config.options.background.lockscreenWallpaperPath)
                Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLockscreen"]);
        }
        StyledToolTip {
            text: Translation.tr("Use a different wallpaper on the lockscreen with custom Matugen color scheme transition")
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        active: Config.options.background.useSeparateLockscreenWallpaper
        asynchronous: true
        sourceComponent: RowLayout {
            Layout.fillWidth: true

            ConfigWallpaperSelector {
                targetMode: "lockscreen"
                text: Translation.tr("Lockscreen Wallpaper Selector")
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                RippleButtonWithIcon {
                    useDynamicRadius: true
                    Layout.fillWidth: true
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Select Lockscreen Wallpaper")
                    onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLockscreen"])
                }

                RippleButtonWithIcon {
                    useDynamicRadius: true
                    Layout.fillWidth: true
                    materialIcon: "swap_horiz"
                    mainText: Translation.tr("Swap Desktop & Lockscreen Wallpapers")
                    onClicked: {
                        const desktopWall = Config.options.background.wallpaperPath;
                        const lockWall = Config.options.background.lockscreenWallpaperPath;
                        if (desktopWall && lockWall) {
                            Config.options.background.wallpaperPath = lockWall;
                            Wallpapers.applyLockscreen(desktopWall);
                            Wallpapers.apply(lockWall);
                        }
                    }
                }
            }
        }
    }

    ContentSubsectionLabel {
        text: Translation.tr("Light-mode wallpaper")
    }

    ConfigSwitch {
        buttonIcon: "light_mode"
        text: Translation.tr("Separate Light Mode Wallpaper")
        checked: Config.options.background.useSeparateLightModeWallpaper
        onCheckedChanged: {
            Config.options.background.useSeparateLightModeWallpaper = checked;
            if (checked && !Config.options.background.lightModeWallpaperPath)
                Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLightmode"]);
        }
        StyledToolTip {
            text: Translation.tr("Use a different wallpaper when in light mode. The current desktop wallpaper will be used for dark mode.")
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        active: Config.options.background.useSeparateLightModeWallpaper
        asynchronous: true
        sourceComponent: RowLayout {
            Layout.fillWidth: true

            ConfigWallpaperSelector {
                targetMode: "lightmode"
                text: Translation.tr("Light Mode Wallpaper Selector")
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                RippleButtonWithIcon {
                    useDynamicRadius: true
                    Layout.fillWidth: true
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Select Light Mode Wallpaper")
                    onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLightmode"])
                }

                RippleButtonWithIcon {
                    useDynamicRadius: true
                    Layout.fillWidth: true
                    materialIcon: "swap_horiz"
                    mainText: Translation.tr("Swap Dark & Light Wallpapers")
                    onClicked: {
                        const darkWall = Config.options.background.wallpaperPath;
                        const lightWall = Config.options.background.lightModeWallpaperPath;
                        if (darkWall && lightWall) {
                            Config.options.background.wallpaperPath = lightWall;
                            Config.options.background.lightModeWallpaperPath = darkWall;
                            if (Appearance.m3colors.darkmode)
                                Wallpapers.apply(darkWall, true);
                            else
                                Wallpapers.applyLightModeWallpaper(lightWall);
                        }
                    }
                }
            }
        }
    }
}
