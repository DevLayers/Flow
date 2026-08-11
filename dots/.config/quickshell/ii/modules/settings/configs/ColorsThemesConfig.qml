import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: colorsThemesRoot
    anchors.fill: parent

    property alias contentY: pageRoot.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: pageRoot
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

    property bool showRestartFab: false

    Connections {
        target: Config.options.appearance.palette
        function onTypeChanged() {
            pageRoot.showRestartFab = true;
        }
    }

    Connections {
        target: Appearance.m3colors
        function onDarkmodeChanged() {
            pageRoot.showRestartFab = true;
        }
    }

    FloatingActionButton {
        id: restartFab
        parent: pageRoot.parent
        anchors {
            right: parent ? parent.right : undefined
            bottom: parent ? parent.bottom : undefined
            margins: 30
        }
        z: 100
        iconText: "restart_alt"
        buttonText: Translation.tr("Restart Shell")
        expanded: false
        visible: opacity > 0
        opacity: pageRoot.showRestartFab ? 1 : 0
        scale: opacity

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        colBackground: Appearance.colors.colTertiaryContainer
        colBackgroundHover: Appearance.colors.colTertiaryContainerHover
        colRipple: Appearance.colors.colTertiaryContainerActive
        colOnBackground: Appearance.colors.colOnTertiaryContainer

        onClicked: {
            Quickshell.execDetached(["bash", "-c", "qs kill -c ii && qs -c ii &"]);
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: restartFab.expanded = true
            onExited: restartFab.expanded = false
        }
    }

    ContentSection {
        title: Translation.tr("Appearance Preferences")
        icon: "palette"

        RowLayout {
            Layout.fillWidth: true

            ConfigWallpaperSelector {
                text: Translation.tr("Wallpaper Selector")
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true

                ConfigLightDarkToggle {
                    text: Translation.tr("Light / Dark Theme")
                }

                Item {
                    id: colorGridItem
                    z: 1
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    StyledFlickable {
                        id: flickable
                        anchors.fill: parent
                        contentHeight: contentLayout.implicitHeight
                        contentWidth: width
                        clip: true

                        ColumnLayout {
                            id: contentLayout
                            width: flickable.width

                            Repeater {
                                model: [
                                    {
                                        customTheme: false,
                                        builtInTheme: false
                                    },
                                    {
                                        customTheme: false,
                                        builtInTheme: true
                                    },
                                    {
                                        customTheme: true,
                                        builtInTheme: false
                                    }
                                ]

                                delegate: ColorPreviewGrid {
                                    customTheme: modelData.customTheme
                                    builtInTheme: modelData.builtInTheme
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Color Engine")
        icon: "science"

        ContentSubsection {
            title: Translation.tr("Color generation mode")
            icon: "settings_brightness"
            tooltip: Translation.tr("ii-vynx: uses the original switchwall pipeline.\n\nFork: uses the fork's color generation pipeline, use this if vynx doesn't work.")
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: Config.options.appearance.colorEngine ?? "vynx"
                onSelected: newValue => {
                    Config.options.appearance.colorEngine = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("ii-vynx"),
                        value: "vynx",
                        icon: "verified"
                    },
                    {
                        displayName: Translation.tr("Fork"),
                        value: "fork",
                        icon: "build"
                    }
                ]
            }
        }
    }

    ContentSection {
        icon: "nightlight"
        title: Translation.tr("Scheduling (Dark Mode & Night Light)")

        ConfigSwitch {
            buttonIcon: "dark_mode"
            text: Translation.tr("Automatic Dark Mode")
            checked: Config.options.light.darkMode.automatic
            onCheckedChanged: {
                Config.options.light.darkMode.automatic = checked;
            }
        }

        MaterialTextArea {
            enabled: Config.options.light.darkMode.automatic
            Layout.fillWidth: true
            placeholderText: Translation.tr("Dark Mode start time (e.g. 18:00)")
            text: Config.options.light.darkMode.from
            wrapMode: TextEdit.NoWrap
            onTextChanged: {
                Config.options.light.darkMode.from = text;
            }
        }

        MaterialTextArea {
            enabled: Config.options.light.darkMode.automatic
            Layout.fillWidth: true
            placeholderText: Translation.tr("Dark Mode end time (e.g. 06:00)")
            text: Config.options.light.darkMode.to
            wrapMode: TextEdit.NoWrap
            onTextChanged: {
                Config.options.light.darkMode.to = text;
            }
        }

        ConfigSwitch {
            buttonIcon: "nightlight_round"
            text: Translation.tr("Automatic Night Light")
            checked: Config.options.light.night.automatic
            onCheckedChanged: {
                Config.options.light.night.automatic = checked;
            }
        }

        MaterialTextArea {
            enabled: Config.options.light.night.automatic
            Layout.fillWidth: true
            placeholderText: Translation.tr("Night Light start time (e.g. 19:00)")
            text: Config.options.light.night.from
            wrapMode: TextEdit.NoWrap
            onTextChanged: {
                Config.options.light.night.from = text;
            }
        }

        MaterialTextArea {
            enabled: Config.options.light.night.automatic
            Layout.fillWidth: true
            placeholderText: Translation.tr("Night Light end time (e.g. 06:00)")
            text: Config.options.light.night.to
            wrapMode: TextEdit.NoWrap
            onTextChanged: {
                Config.options.light.night.to = text;
            }
        }

        ConfigSlider {
            buttonIcon: "wb_twilight"
            text: Translation.tr("Night Light Color Temperature")
            usePercentTooltip: false
            from: 1000
            to: 10000
            stepSize: 100
            value: Config.options.light.night.colorTemperature ?? 5000
            onValueChanged: {
                Config.options.light.night.colorTemperature = Math.round(value);
            }
        }

        ContentSubsection {
            title: Translation.tr("Remember Night Light")
            icon: "history"
            tooltip: Translation.tr("Restores the Night Light toggle and gamma level after a restart. With automatic mode on, a restored toggle still gives way at the next start or end time.")
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: Config.options.light.night.persistManual
                onSelected: newValue => {
                    Config.options.light.night.persistManual = newValue;
                }
                options: [
                    {
                        "displayName": Translation.tr("Never"),
                        "icon": "block",
                        "value": "never"
                    },
                    {
                        "displayName": Translation.tr("Until reboot"),
                        "icon": "restart_alt",
                        "value": "session"
                    },
                    {
                        "displayName": Translation.tr("Always"),
                        "icon": "all_inclusive",
                        "value": "always"
                    }
                ]
            }
        }

        ConfigSwitch {
            buttonIcon: "flash_off"
            text: Translation.tr("Anti-flashbang light filter")
            checked: Config.options.light.antiFlashbang.enable
            onCheckedChanged: {
                Config.options.light.antiFlashbang.enable = checked;
            }
        }
    }

    ContentSection {
        title: Translation.tr("Wallpaper Theming & Matugen Integration")
        icon: "wallpaper"

        ContentSubsectionLabel {
            text: Translation.tr("Application theming")
        }

            ConfigSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Shell & utilities")
                checked: Config.options.appearance.wallpaperTheming.enableAppsAndShell
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableAppsAndShell = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Qt apps")
                checked: Config.options.appearance.wallpaperTheming.enableQtApps
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableQtApps = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Shell & utilities theming must also be enabled")
                }
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Terminal")
                checked: Config.options.appearance.wallpaperTheming.enableTerminal
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableTerminal = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Shell & utilities theming must also be enabled")
                }
            }
    }

    ContentSection {
        title: Translation.tr("Wallpaper Picker")
        icon: "folder_open"

        ConfigSwitch {
            buttonIcon: "folder_shared"
            text: Translation.tr("Use system file picker")
            checked: Config.options.wallpaperSelector.useSystemFileDialog
            onCheckedChanged: {
                Config.options.wallpaperSelector.useSystemFileDialog = checked;
            }
            StyledToolTip {
                text: Translation.tr("Uses xdg-desktop-portal instead of the built-in quickshell picker")
            }
        }
    }

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
                    if (checked && !Config.options.background.lockscreenWallpaperPath) {
                        Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLockscreen"]);
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Use a different wallpaper on the lockscreen with custom Matugen color scheme transition")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Config.options.background.useSeparateLockscreenWallpaper

                ConfigWallpaperSelector {
                    targetMode: "lockscreen"
                    text: Translation.tr("Lockscreen Wallpaper Selector")
                }

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        useDynamicRadius: true
                        Layout.fillWidth: true
                        materialIcon: "wallpaper"
                        mainText: Translation.tr("Select Lockscreen Wallpaper")
                        onClicked: {
                            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLockscreen"]);
                        }
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
        ContentSubsectionLabel {
            text: Translation.tr("Light-mode wallpaper")
        }

            ConfigSwitch {
                buttonIcon: "light_mode"
                text: Translation.tr("Separate Light Mode Wallpaper")
                checked: Config.options.background.useSeparateLightModeWallpaper
                onCheckedChanged: {
                    Config.options.background.useSeparateLightModeWallpaper = checked;
                    if (checked && !Config.options.background.lightModeWallpaperPath) {
                        Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLightmode"]);
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Use a different wallpaper when in light mode. The current desktop wallpaper will be used for dark mode.")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Config.options.background.useSeparateLightModeWallpaper

                ConfigWallpaperSelector {
                    targetMode: "lightmode"
                    text: Translation.tr("Light Mode Wallpaper Selector")
                }

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        useDynamicRadius: true
                        Layout.fillWidth: true
                        materialIcon: "wallpaper"
                        mainText: Translation.tr("Select Light Mode Wallpaper")
                        onClicked: {
                            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggleLightmode"]);
                        }
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
                                // Re-apply current mode's wallpaper
                                if (Appearance.m3colors.darkmode) {
                                    Wallpapers.apply(darkWall, true);
                                } else {
                                    Wallpapers.applyLightModeWallpaper(lightWall);
                                }
                            }
                        }
                    }
                }
            }
    }

    ContentSection {
        title: Translation.tr("OpenRGB Integration")
        icon: "palette"

        ConfigSwitch {
            buttonIcon: "palette"
            text: Translation.tr("OpenRGB integration")
            checked: Config.options.appearance.openrgb.enable
            configPage: Qt.resolvedUrl("widgets/OpenRGBConfig.qml")
            onCheckedChanged: {
                Config.options.appearance.openrgb.enable = checked;
            }
        }
    }
    ContentSection {
        title: Translation.tr("Linux Wallpaper Engine")
        icon: "wallpaper"

        ConfigSwitch {
            buttonIcon: "play_circle"
            text: Translation.tr("Enable Wallpaper Engine")
            checked: Config.options.background.useWallpaperEngine
            configPage: Qt.resolvedUrl("widgets/WallpaperEngineConfig.qml")
            onCheckedChanged: {
                if (Config.options.background.useWallpaperEngine === checked)
                    return;
                Config.options.background.useWallpaperEngine = checked;
                Config.saveOptionsNow();
                if (checked && Config.options.background.wallpaperEngineId) {
                    Wallpapers.apply(Config.options.background.wallpaperEngineId);
                } else if (!checked) {
                    Quickshell.execDetached(["bash", "-c", "pkill -f linux-wallpaperengine; sleep 0.3; pkill -9 -f linux-wallpaperengine 2>/dev/null; true"]);
                    if (Config.options.background.wallpaperPath)
                        Wallpapers.apply(Config.options.background.wallpaperPath);
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Wallpaper Browser")
        icon: "download"

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Wallpaper Browser download path")
            text: Config.options.wallpapers.paths.download
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.wallpapers.paths.download = text;
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
