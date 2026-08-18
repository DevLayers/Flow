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

            if (rule === "show")
                always.push(name);
            else if (rule === "hide")
                never.push(name);

            conf.neverShowApps = never;
            conf.alwaysShowApps = always;
        }

        // Apps with explicit rules, then (while searching) installed apps and
        // the raw query as a free-text fallback, since notification app names
        // can differ from any desktop entry
        readonly property var displayedApps: {
            const lowerQuery = query.toLowerCase();
            const taken = new Set();
            const result = [];
            const add = (name, icon) => {
                if (!name || taken.has(name.toLowerCase()))
                    return;
                taken.add(name.toLowerCase());
                result.push({
                    name: name,
                    icon: icon
                });
            };
            const matches = name => lowerQuery === "" || name.toLowerCase().includes(lowerQuery);

            [...conf.alwaysShowApps, ...conf.neverShowApps].filter(matches).forEach(name => add(name, ""));
            if (lowerQuery !== "") {
                AppSearch.fuzzyQuery(query).slice(0, 8).forEach(entry => add(entry.name, entry.icon));
                add(query, "");
            }
            return result;
        }

        spacing: 8

        ConfigSelectionArray {
            currentValue: editor.conf.defaultPolicy
            onSelected: newValue => {
                editor.conf.defaultPolicy = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Show by default"),
                    icon: "visibility",
                    value: "show"
                },
                {
                    displayName: Translation.tr("Hide by default"),
                    icon: "visibility_off",
                    value: "hide"
                }
            ]
        }

        MaterialTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Search apps or type a name")
        }

        StyledText {
            visible: editor.displayedApps.length === 0
            Layout.fillWidth: true
            text: Translation.tr("No rules yet. Search to pick an installed app, or type any name a notification reports.")
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Repeater {
            model: editor.displayedApps
            delegate: RowLayout {
                id: appRow
                required property var modelData
                readonly property string rule: editor.ruleFor(modelData.name)

                Layout.fillWidth: true
                spacing: 10

                IconImage {
                    implicitSize: 28
                    source: Quickshell.iconPath(appRow.modelData.icon !== "" ? appRow.modelData.icon : AppSearch.guessIcon(appRow.modelData.name), "image-missing")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: appRow.modelData.name
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnSecondaryContainer
                }

                SelectionGroupButton {
                    leftmost: true
                    buttonIcon: "remove"
                    toggled: appRow.rule === "default"
                    onClicked: editor.setRule(appRow.modelData.name, "default")
                    StyledToolTip {
                        text: Translation.tr("Follow default")
                    }
                }
                SelectionGroupButton {
                    buttonIcon: "visibility"
                    toggled: appRow.rule === "show"
                    onClicked: editor.setRule(appRow.modelData.name, "show")
                    StyledToolTip {
                        text: Translation.tr("Always show")
                    }
                }
                SelectionGroupButton {
                    rightmost: true
                    buttonIcon: "visibility_off"
                    toggled: appRow.rule === "hide"
                    onClicked: editor.setRule(appRow.modelData.name, "hide")
                    StyledToolTip {
                        text: Translation.tr("Never show")
                    }
                }
            }
        }
    }
}
