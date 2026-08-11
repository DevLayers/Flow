import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

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
                text: Translation.tr("Lockscreen Notifications")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Display & Position")
            icon: "notifications"

            ContentSubsection {
                title: Translation.tr("Position")
                icon: "picture_in_picture"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.lock.notifications.position
                    onSelected: newValue => {
                        Config.options.lock.notifications.position = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top left"),
                            icon: "north_west",
                            value: "top_left"
                        },
                        {
                            displayName: Translation.tr("Top right"),
                            icon: "north_east",
                            value: "top_right"
                        },
                        {
                            displayName: Translation.tr("Bottom left"),
                            icon: "south_west",
                            value: "bottom_left"
                        },
                        {
                            displayName: Translation.tr("Bottom right"),
                            icon: "south_east",
                            value: "bottom_right"
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Privacy level")
                icon: "visibility"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.lock.notifications.privacy
                    onSelected: newValue => {
                        Config.options.lock.notifications.privacy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Full content"),
                            icon: "visibility",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Hide content"),
                            icon: "visibility_off",
                            value: "redacted"
                        },
                        {
                            displayName: Translation.tr("Count only"),
                            icon: "numbers",
                            value: "countOnly"
                        }
                    ]
                }
            }

            ConfigSwitch {
                buttonIcon: "history"
                text: Translation.tr("Only notifications received while locked")
                checked: Config.options.lock.notifications.onlySinceLock
                onCheckedChanged: {
                    Config.options.lock.notifications.onlySinceLock = checked;
                }
            }

            ConfigSpinBox {
                icon: "format_list_numbered"
                text: Translation.tr("Maximum notifications shown")
                value: Config.options.lock.notifications.maxShown
                from: 1
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.options.lock.notifications.maxShown = value;
                }
            }

            ConfigSpinBox {
                icon: "zoom_in"
                text: Translation.tr("Notification size (%)")
                value: Config.options.lock.notifications.zoomPercent
                from: 50
                to: 200
                stepSize: 10
                onValueChanged: {
                    Config.options.lock.notifications.zoomPercent = value;
                }
            }
        }

        ContentSection {
            title: Translation.tr("App Rules & Filters")
            icon: "filter_list"

            ContentSubsection {
                title: Translation.tr("App rules")
                icon: "apps"
                Layout.fillWidth: true

                AppRulesEditor {}
            }

            ContentSubsectionLabel {
                text: Translation.tr("Filters")
            }

            ConfigSwitch {
                buttonIcon: "hourglass_disabled"
                text: Translation.tr("Hide transient notifications")
                checked: Config.options.lock.notifications.filters.skipTransient
                onCheckedChanged: {
                    Config.options.lock.notifications.filters.skipTransient = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "low_priority"
                text: Translation.tr("Hide low-urgency notifications")
                checked: Config.options.lock.notifications.filters.skipLowUrgency
                onCheckedChanged: {
                    Config.options.lock.notifications.filters.skipLowUrgency = checked;
                }
            }

            ContentSubsection {
                title: Translation.tr("Critical notifications")
                icon: "priority_high"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.lock.notifications.filters.criticalOverride
                    onSelected: newValue => {
                        Config.options.lock.notifications.filters.criticalOverride = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Always show full"),
                            icon: "priority_high",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("No exception"),
                            icon: "do_not_disturb_on",
                            value: "none"
                        }
                    ]
                }
            }
        }
    }

    component AppRulesEditor: ColumnLayout {
        id: editor

        readonly property var conf: Config.options.lock.notifications
        readonly property string query: searchField.text.trim()

        function ruleFor(name) {
            const lower = name.toLowerCase();
            if (conf.neverShowApps.some(app => app.toLowerCase() === lower))
                return "hide";
            if (conf.alwaysShowApps.some(app => app.toLowerCase() === lower))
                return "show";
            return "default";
        }

        function setRule(name, rule) {
            const lower = name.toLowerCase();
            let never = conf.neverShowApps.filter(app => app.toLowerCase() !== lower);
            let always = conf.alwaysShowApps.filter(app => app.toLowerCase() !== lower);

            if (rule === "hide")
                never.push(name);
            else if (rule === "show")
                always.push(name);

            conf.neverShowApps = never;
            conf.alwaysShowApps = always;
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Filter apps...")
            }
        }

        Repeater {
            model: AppSearch.appList

            delegate: ColumnLayout {
                id: delegateRoot
                required property var modelData
                required property int index

                readonly property string appName: modelData.name || modelData.appId || ""
                readonly property string currentRule: editor.ruleFor(appName)
                readonly property bool matchesSearch: editor.query === "" || appName.toLowerCase().indexOf(editor.query.toLowerCase()) !== -1

                visible: matchesSearch
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppIcon {
                        implicitWidth: 24
                        implicitHeight: 24
                        appIcon: delegateRoot.modelData.icon || "application-x-executable"
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateRoot.appName
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 2

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.full
                            colBackground: delegateRoot.currentRule === "default" ? Appearance.colors.colPrimaryContainer : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "remove"
                                iconSize: 16
                                color: delegateRoot.currentRule === "default" ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            }

                            StyledToolTip {
                                text: Translation.tr("Default (use global privacy settings)")
                            }

                            onClicked: editor.setRule(delegateRoot.appName, "default")
                        }

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.full
                            colBackground: delegateRoot.currentRule === "hide" ? Appearance.colors.colErrorContainer : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "block"
                                iconSize: 16
                                color: delegateRoot.currentRule === "hide" ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer1
                            }

                            StyledToolTip {
                                text: Translation.tr("Always hide on lockscreen")
                            }

                            onClicked: editor.setRule(delegateRoot.appName, "hide")
                        }

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.full
                            colBackground: delegateRoot.currentRule === "show" ? Appearance.colors.colSecondaryContainer : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "visibility"
                                iconSize: 16
                                color: delegateRoot.currentRule === "show" ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }

                            StyledToolTip {
                                text: Translation.tr("Always show full content")
                            }

                            onClicked: editor.setRule(delegateRoot.appName, "show")
                        }
                    }
                }
            }
        }
    }
}
