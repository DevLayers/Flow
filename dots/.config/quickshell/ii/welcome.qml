//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 12
    property bool showNextTime: false
    visible: true

    onClosing: {
        Quickshell.execDetached(["notify-send", Translation.tr("Welcome app"), Translation.tr("Enjoy! You can reopen the welcome app any time with <tt>Super+Shift+Alt+/</tt>. To open the settings app, hit <tt>Super+I</tt>"), "-a", "Shell"]);
        Qt.quit();
    }
    title: "illogical-impulse Welcome"

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0;
    }

    minimumWidth: 850
    minimumHeight: 600
    width: 1050
    height: 740
    color: Appearance.m3colors.m3background

    Process {
        id: konachanWallProc
        property string status: ""
        command: ["bash", "-c", Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]
        stdout: SplitParser {
            onRead: data => {
                console.log(`Konachan wall proc output: ${data}`);
                konachanWallProc.status = data.trim();
            }
        }
    }

    // Keybind badge helper component
    component KeybindItem: Rectangle {
        id: keybindItemRoot
        required property string title
        required property string key1
        property string key2: ""
        property string key3: ""

        implicitWidth: 230
        implicitHeight: 65
        color: Appearance.colors.colLayer2
        radius: Appearance.rounding.normal

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: keybindItemRoot.title
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 3
                KeyboardKey {
                    key: keybindItemRoot.key1
                }
                StyledText {
                    visible: keybindItemRoot.key2 !== ""
                    text: "+"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer3
                }
                KeyboardKey {
                    visible: keybindItemRoot.key2 !== ""
                    key: keybindItemRoot.key2
                }
                StyledText {
                    visible: keybindItemRoot.key3 !== ""
                    text: "+"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer3
                }
                KeyboardKey {
                    visible: keybindItemRoot.key3 !== ""
                    key: keybindItemRoot.key3
                }
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }
        spacing: 10

        // Titlebar
        Item {
            visible: Config.options?.windows?.showTitlebar ?? true
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)

            StyledText {
                id: welcomeText
                anchors {
                    left: Config.options?.windows?.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options?.windows?.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Quick Actions & Welcome")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }

            RowLayout {
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 8

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Show next time")
                }
                StyledSwitch {
                    id: showNextTimeSwitch
                    checked: root.showNextTime
                    scale: 0.7
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
                        }
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: Appearance.font.pixelSize.normal
                    }
                    StyledToolTip {
                        text: Translation.tr("Close (Super+Q)")
                    }
                }
            }
        }

        // Main Content Container
        Rectangle {
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            Layout.fillWidth: true
            Layout.fillHeight: true

            ContentPage {
                id: contentColumn
                anchors.fill: parent

                // Hero / Banner Card: Quick Open Settings
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 90
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimaryContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 16

                        // Settings Icon inside rounded shape container
                        Rectangle {
                            width: 52
                            height: 52
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colPrimary

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "settings"
                                fill: 1
                                iconSize: Appearance.font.pixelSize.huge
                                color: Appearance.colors.colOnPrimary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: Translation.tr("illogical-impulse Shell Control")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.bold: true
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: Translation.tr("Quick access to key toggles, theme settings, and system shortcuts")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            materialIcon: "settings"
                            mainText: Translation.tr("Open Full Settings")
                            colBackground: Appearance.colors.colPrimary
                            colText: Appearance.colors.colOnPrimary
                            onClicked: {
                                Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "settings", "toggle"]);
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 8
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.bold: true
                                        text: Translation.tr("Open Settings")
                                        color: Appearance.colors.colOnPrimary
                                    }
                                    RowLayout {
                                        spacing: 2
                                        KeyboardKey { key: "󰖳" }
                                        KeyboardKey { key: "I" }
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 1: Appearance & Theme
                ContentSection {
                    icon: "format_paint"
                    title: Translation.tr("Appearance & Theme")

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ConfigWallpaperSelector {
                            text: Translation.tr("Wallpaper")
                            implicitWidth: 360
                            implicitHeight: 202.5
                            Layout.preferredWidth: 360
                            Layout.preferredHeight: 202.5
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ConfigLightDarkToggle {
                                text: Translation.tr("Light / Dark Theme")
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 142.5

                                StyledFlickable {
                                    anchors.fill: parent
                                    contentHeight: colorGrid.implicitHeight
                                    contentWidth: width
                                    clip: true

                                    ColorPreviewGrid {
                                        id: colorGrid
                                        width: parent.width
                                        customTheme: false
                                        builtInTheme: false
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 10
                                RippleButtonWithIcon {
                                    id: rndWallBtn
                                    visible: Config.options?.policies?.weeb === 1
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "ifl"
                                    mainText: konachanWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random Konachan Wallpaper")
                                    onClicked: {
                                        konachanWallProc.running = true;
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Random SFW Anime wallpaper from Konachan")
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 2: Shell Style (Connect vs Default Mode)
                ContentSection {
                    icon: "dashboard_customize"
                    title: Translation.tr("Shell Mode Style")

                    NoticeBox {
                        Layout.fillWidth: true
                        text: Translation.tr("Select how the shell UI is structured: Default Mode uses a top bar with concave curves. Connect Mode integrates a floating Dynamic Island and mobile drop overlays.")
                    }

                    ConfigSelectionArray {
                        currentValue: Config.options.sidebar.sidebarStyle
                        onSelected: newValue => {
                            Config.options.sidebar.sidebarStyle = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Default Mode"),
                                icon: "view_sidebar",
                                value: "default"
                            },
                            {
                                displayName: Translation.tr("Connect Mode"),
                                icon: "phone_android",
                                value: "connect"
                            }
                        ]
                    }
                }

                // Section 3: Keybinds
                ContentSection {
                    icon: "keyboard"
                    title: Translation.tr("Essential Shortcuts")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        KeybindItem {
                            title: Translation.tr("Settings App")
                            key1: "󰖳"
                            key2: "I"
                        }
                        KeybindItem {
                            title: Translation.tr("Left Sidebar (AI)")
                            key1: "󰖳"
                            key2: "A"
                        }
                        KeybindItem {
                            title: Translation.tr("Right Sidebar (Control)")
                            key1: "󰖳"
                            key2: "N"
                        }
                        KeybindItem {
                            title: Translation.tr("Overview")
                            key1: "󰖳"
                            key2: "Tab"
                        }
                        KeybindItem {
                            title: Translation.tr("App Launcher")
                            key1: "󰖳"
                            key2: "Space"
                        }
                        KeybindItem {
                            title: Translation.tr("Keybinds Cheatsheet")
                            key1: "󰖳"
                            key2: "/"
                        }
                        KeybindItem {
                            title: Translation.tr("Welcome App")
                            key1: "󰖳"
                            key2: "Shift"
                            key3: "/"
                        }
                        KeybindItem {
                            title: Translation.tr("Wallpaper Picker")
                            key1: "Ctrl"
                            key2: "󰖳"
                            key3: "T"
                        }
                    }
                }

                // Section 4: Links & Community
                ContentSection {
                    icon: "link"
                    title: Translation.tr("Project & Links")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        RippleButtonWithIcon {
                            nerdIcon: "󰊤"
                            mainText: "GitHub Repo (ii-p3drovfx)"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/P3DROVFX/ii-p3drovfx");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "account_circle"
                            mainText: "Developer Profile (P3DROVFX)"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/P3DROVFX");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "help"
                            mainText: Translation.tr("Documentation Wiki")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/");
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 10
                }
            }
        }
    }
}
