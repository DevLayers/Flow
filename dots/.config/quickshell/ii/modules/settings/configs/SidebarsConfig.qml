import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: sidebarsRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        property bool showBackButton: false
        signal goBack()

        RowLayout {
            spacing: 12
            visible: page.showBackButton

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
                onClicked: page.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: Translation.tr("Sidebars")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            icon: "policy"
            title: Translation.tr("Sidebar Policies Visibility")

            NoticeBox {
                Layout.fillWidth: true
                isFirst: true
                text: Translation.tr("Choose which policy tabs are visible in the left sidebar when it is opened.")
            }

            ConfigToggleGrid {
                Layout.fillWidth: true
                gridColumns: Math.max(1, Math.floor(parent.width / 300))
                currentValues: {
                    return {
                        "ai": Config.options.policies.ai,
                        "weeb": Config.options.policies.weeb,
                        "wallpapers": Config.options.policies.wallpapers,
                        "translator": Config.options.policies.translator,
                        "player": Config.options.policies.player,
                        "phone": Config.options.policies.phone
                    };
                }
                model: [{
                    "key": "ai",
                    "name": Translation.tr("AI"),
                    "icon": "smart_toy",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }, {
                        "displayName": Translation.tr("Local"),
                        "icon": "sync_saved_locally",
                        "value": 2
                    }]
                }, {
                    "key": "weeb",
                    "name": Translation.tr("Weeb"),
                    "icon": "face",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }, {
                        "displayName": Translation.tr("Closet"),
                        "icon": "ev_shadow",
                        "value": 2
                    }]
                }, {
                    "key": "wallpapers",
                    "name": Translation.tr("Wallpaper browser"),
                    "icon": "wallpaper",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }]
                }, {
                    "key": "translator",
                    "name": Translation.tr("Translator"),
                    "icon": "translate",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }]
                }, {
                    "key": "player",
                    "name": Translation.tr("Sidebar player"),
                    "icon": "music_note",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }]
                }, {
                    "key": "phone",
                    "name": Translation.tr("Phone"),
                    "icon": "smartphone",
                    "options": [{
                        "displayName": Translation.tr("No"),
                        "icon": "close",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Yes"),
                        "icon": "check",
                        "value": 1
                    }]
                }]
                onItemChanged: (key, value) => {
                    Config.options.policies[key] = value;
                }
            }
        }

        ContentSection {
            title: Translation.tr("Right Control Sidebar")
            icon: "view_sidebar"

            ConfigSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Keep right sidebar loaded")
                checked: Config.options.sidebar.keepRightSidebarLoaded
                onCheckedChanged: {
                    if (Config.ready && checked !== Config.options.sidebar.keepRightSidebarLoaded)
                        Config.options.sidebar.keepRightSidebarLoaded = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Show media player in volume dialog")
                checked: Config.options.sidebar.volumeDialogMediaWidget
                onCheckedChanged: {
                    Config.options.sidebar.volumeDialogMediaWidget = checked;
                }
            }

            ContentSubsection {
                title: Translation.tr("Sidebar position")
                icon: "switch_right"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.sidebar.position
                    onSelected: (newValue) => {
                        Config.options.sidebar.position = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Default"),
                        "icon": "vertical_align_center",
                        "value": "default"
                    }, {
                        "displayName": Translation.tr("Inverted"),
                        "icon": "swap_horiz",
                        "value": "inverted"
                    }, {
                        "displayName": Translation.tr("Left"),
                        "icon": "keyboard_arrow_left",
                        "value": "left"
                    }, {
                        "displayName": Translation.tr("Right"),
                        "icon": "keyboard_arrow_right",
                        "value": "right"
                    }]
                }
            }
        }

        ContentSection {
            title: Translation.tr("Quick Toggles & Sliders")
            icon: "tune"

            ConfigSwitch {
                buttonIcon: "tune"
                text: Translation.tr("Quick toggles and slider settings")
                checked: true
                configPage: Qt.resolvedUrl("widgets/SidebarQuickTogglesConfig.qml")
                StyledToolTip {
                    text: Translation.tr("Click button text to configure quick toggle styles, column counts, 2x1 capsule sliders, and fixed sliders.")
                }
            }
        }

        ContentSection {
            title: Translation.tr("Screen Corners")
            icon: "mouse"

            ConfigSwitch {
                buttonIcon: "touch_app"
                text: Translation.tr("Enable corner open")
                checked: Config.options.sidebar.cornerOpen.enable
                configPage: Qt.resolvedUrl("widgets/ScreenCornersConfig.qml")
                property bool readyForToggle: false
                Component.onCompleted: readyForToggle = true
                onCheckedChanged: {
                    if (!readyForToggle || !Config.ready)
                        return;
                    Config.options.sidebar.cornerOpen.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Toggle corner open activation. Click button text to configure hover trigger, vertical offset, and region bounds.")
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
