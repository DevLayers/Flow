import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Advanced AI settings sub-page.
 *
 * Tool permissions, request limits and attachment limits are set once and
 * then left alone, so they moved off the main AI page — where their many
 * rows made the dashboard long and tiring to scroll — into this sub-page,
 * reached from the "Advanced settings" entry button.
 */
ContentPage {
    id: page

    property bool showBackButton: false
    signal goBack()

    forceWidth: false

    readonly property var toolDefinitions: Array.from(Ai.toolbox.definitions)

    RowLayout {
        visible: page.showBackButton
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
            onClicked: page.goBack()

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        StyledText {
            text: Translation.tr("Advanced AI Settings")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "service_toolbox"
        title: Translation.tr("Tools")

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options.ai.tools.mode
            onSelected: newValue => {
                Config.options.ai.tools.mode = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Tools"),
                    icon: "build",
                    value: "functions"
                },
                {
                    displayName: Translation.tr("Web search"),
                    icon: "travel_explore",
                    value: "search"
                },
                {
                    displayName: Translation.tr("None"),
                    icon: "block",
                    value: "none"
                }
            ]
        }

        ContentSubsection {
            title: Translation.tr("When each tool may run")
            tooltip: Translation.tr("Applies to the Tools mode. A tool set to ask stops for approval every time, and shows what it would do first.")

            Repeater {
                model: page.toolDefinitions

                ColumnLayout {
                    id: toolEntry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: toolEntry.modelData.icon
                            iconSize: Appearance.font.pixelSize.huge
                            color: toolEntry.modelData.risk === "danger" ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: toolEntry.modelData.title
                                wrapMode: Text.Wrap
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: toolEntry.modelData.summary
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Ai.toolbox.permission(toolEntry.modelData.id)
                        onSelected: newValue => {
                            Ai.toolbox.setPermission(toolEntry.modelData.id, newValue);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Always"),
                                icon: "check_circle",
                                value: "allow"
                            },
                            {
                                displayName: Translation.tr("Ask first"),
                                icon: "help",
                                value: "ask"
                            },
                            {
                                displayName: Translation.tr("Never"),
                                icon: "block",
                                value: "deny"
                            }
                        ]
                    }
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "rate_review"
            text: Translation.tr("Show settings changes before applying them")
            checked: Config.options.ai.tools.reviewConfigChanges
            onCheckedChanged: {
                Config.options.ai.tools.reviewConfigChanges = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "home_storage"
            text: Translation.tr("Let local models use tools")
            checked: Config.options.ai.tools.localModels
            onCheckedChanged: {
                Config.options.ai.tools.localModels = checked;
            }
        }

        ConfigSpinBox {
            icon: "history"
            text: Translation.tr("Tool calls to remember")
            value: Config.options.ai.tools.logSize
            from: 0
            to: 200
            stepSize: 10
            onValueChanged: {
                Config.options.ai.tools.logSize = value;
            }
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("Requests")

        ConfigSpinBox {
            icon: "notes"
            text: Translation.tr("Longest answer, in tokens (0 = the model's own limit)")
            value: Config.options.ai.maxOutputTokens
            from: 0
            to: 200000
            stepSize: 1024
            onValueChanged: {
                Config.options.ai.maxOutputTokens = value;
            }
        }

        ConfigSpinBox {
            icon: "cloud_sync"
            text: Translation.tr("Seconds to reach the provider")
            value: Config.options.ai.connectTimeout
            from: 5
            to: 120
            stepSize: 5
            onValueChanged: {
                Config.options.ai.connectTimeout = value;
            }
        }

        ConfigSpinBox {
            icon: "hourglass_top"
            text: Translation.tr("Seconds to finish an answer")
            value: Config.options.ai.requestTimeout
            from: 30
            to: 1800
            stepSize: 30
            onValueChanged: {
                Config.options.ai.requestTimeout = value;
            }
        }

        ConfigSpinBox {
            icon: "refresh"
            text: Translation.tr("Retries after a rate limit or a server error")
            value: Config.options.ai.maxRetries
            from: 0
            to: 5
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxRetries = value;
            }
        }
    }

    ContentSection {
        icon: "attach_file"
        title: Translation.tr("Attachments")

        TipBox {
            Layout.fillWidth: true
            text: Translation.tr("Every attached file is sent again with every following turn of the same chat, so a large one is paid for more than once.")
        }

        ConfigSpinBox {
            icon: "database"
            text: Translation.tr("Biggest file, in MiB")
            value: Config.options.ai.maxAttachmentMib
            from: 1
            to: 20
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxAttachmentMib = value;
            }
        }

        ConfigSpinBox {
            icon: "counter_1"
            text: Translation.tr("Files per message")
            value: Config.options.ai.maxAttachments
            from: 1
            to: 20
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxAttachments = value;
            }
        }
    }
}
