import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * What the assistant may reach for, and what it has reached for.
 *
 * The old panel was three modes and nothing else: a single choice that turned
 * everything on together, with no way to say "read my settings but never run
 * a command" and no record afterwards of what had run. Mode is still the top
 * switch, because a model that cannot call functions has nothing below it to
 * configure — but under it every tool carries its own standing answer, and
 * the log says what actually happened.
 */
Item {
    id: root

    signal closed

    readonly property bool functionsMode: Ai.currentTool === "functions"
    readonly property var definitions: {
        const format = Ai.toolbox.apiFormat;
        return Array.from(Ai.toolbox.definitions).filter(def => def.formats.indexOf(format) !== -1 && (!def.needsSearch || Ai.toolbox.searchAvailable));
    }

    implicitHeight: contentColumnLayout.implicitHeight

    component SectionLabel: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    ColumnLayout {
        id: contentColumnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        SectionLabel {
            Layout.topMargin: 0
            text: Translation.tr("What may it reach for?")
        }

        Repeater {
            model: ScriptModel {
                values: Array.from(Ai.availableTools)
            }

            RippleButton {
                id: modeButton
                required property var modelData

                Layout.fillWidth: true
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                buttonRadius: Appearance.rounding.small
                toggled: Ai.currentTool === modeButton.modelData
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                onClicked: Ai.setTool(modeButton.modelData)

                contentItem: ColumnLayout {
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Ai.toolbox.modeLabels[modeButton.modelData] ?? modeButton.modelData
                        color: modeButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Ai.toolbox.modeDescriptions[modeButton.modelData] ?? ""
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        StyledFlickable {
            Layout.fillWidth: true
            implicitHeight: Math.min(scrolledColumnLayout.implicitHeight, 320)
            contentWidth: width
            contentHeight: scrolledColumnLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: scrolledColumnLayout
                width: parent.width
                spacing: 6

                SectionLabel {
                    visible: root.functionsMode
                    text: Translation.tr("Each tool, and when it may run")
                }

                Repeater {
                    model: ScriptModel {
                        values: root.functionsMode ? root.definitions : []
                    }

                    ColumnLayout {
                        id: toolRow
                        required property var modelData

                        readonly property string permission: Ai.toolbox.permission(toolRow.modelData.id)

                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignTop
                                text: toolRow.modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: toolRow.permission === "deny" ? Appearance.colors.colSubtext : (toolRow.modelData.risk === "danger" ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer2)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: toolRow.modelData.title
                                    color: Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: toolRow.modelData.summary
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }

                        ButtonGroup {
                            // Sizes itself to its buttons, so it is left where
                            // the tool it belongs to starts rather than
                            // stretched across the panel.
                            Layout.leftMargin: 28

                            Repeater {
                                model: Ai.toolbox.permissionValues

                                GroupButton {
                                    id: permissionButton
                                    required property var modelData

                                    toggled: toolRow.permission === permissionButton.modelData
                                    onClicked: Ai.toolbox.setPermission(toolRow.modelData.id, permissionButton.modelData)

                                    contentItem: StyledText {
                                        horizontalAlignment: Text.AlignHCenter
                                        text: Ai.toolbox.permissionLabels[permissionButton.modelData] ?? permissionButton.modelData
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: permissionButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.functionsMode
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Show settings changes before applying them")
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledSwitch {
                        checked: Config.options.ai.tools.reviewConfigChanges
                        onCheckedChanged: Config.options.ai.tools.reviewConfigChanges = checked
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: Ai.toolbox.callLog.length > 0
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Recently used")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    RippleButton {
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 4
                        bottomPadding: 4
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: Ai.toolbox.clearLog()

                        contentItem: StyledText {
                            text: Translation.tr("Clear")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: Array.from(Ai.toolbox.callLog).slice(0, 8)
                    }

                    RowLayout {
                        id: logRow
                        required property var modelData

                        readonly property color statusColor: {
                            if (logRow.modelData.status === "failed")
                                return Appearance.m3colors.m3error;
                            if (logRow.modelData.status === "refused")
                                return Appearance.colors.colSubtext;
                            if (logRow.modelData.status === "running")
                                return Appearance.colors.colPrimary;
                            return Appearance.colors.colOnLayer2;
                        }

                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: logRow.modelData.status === "running" ? "progress_activity" : logRow.modelData.icon
                            iconSize: Appearance.font.pixelSize.larger
                            color: logRow.statusColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledText {
                                    Layout.fillWidth: true
                                    text: logRow.modelData.title
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    text: logRow.modelData.outcome
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: logRow.statusColor
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: logRow.modelData.detail
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }
    }
}
