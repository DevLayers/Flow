import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal trySidebar()
    signal trySearch()

    readonly property int barPosition: (Config.options.bar.bottom ? 1 : 0)
        | (Config.options.bar.vertical ? 2 : 0)
    readonly property bool cornerStyleRestricted: Config.options.bar.barBackgroundStyle === 3
    readonly property bool compactWidth: width < 900

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.rounding.normal

        GridLayout {
            Layout.fillWidth: true
            columns: root.compactWidth ? 1 : 2
            columnSpacing: Appearance.rounding.normal
            rowSpacing: Appearance.rounding.small

            WelcomeShellModeCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                mode: "default"
                title: Translation.tr("Default")
                classification: Translation.tr("INDEPENDENT")
                detailOne: Translation.tr("Sidebar and Search stay independent")
                detailTwo: Translation.tr("Traditional desktop workflow")
                modeIcon: "view_sidebar"
                selected: ShellModePolicy.effectiveMode === "default"
                enabled: ShellModePolicy.canSelectDefault
                Accessible.name: Translation.tr("Default shell mode")
                onModeSelected: ShellModePolicy.setMode("default")
            }

            WelcomeShellModeCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                mode: "connect"
                title: Translation.tr("Connect")
                classification: Translation.tr("UNIFIED")
                detailOne: Translation.tr("Search and panels stay near the bar")
                detailTwo: Translation.tr("Mobile-inspired interaction model")
                modeIcon: "join_full"
                selected: ShellModePolicy.effectiveMode === "connect"
                enabled: ShellModePolicy.canSelectConnect
                Accessible.name: Translation.tr("Connect shell mode")
                onModeSelected: ShellModePolicy.setMode("connect")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Try the selected mode")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                }

            }

            Item {
                Layout.fillWidth: true
            }

            RippleButtonWithIcon {
                implicitWidth: Appearance.rounding.verylarge * 4
                implicitHeight: Appearance.rounding.verylarge
                centerContent: true
                materialIcon: "side_navigation"
                mainText: Translation.tr("Sidebar")
                textPixelSize: Appearance.font.pixelSize.smaller
                iconPixelSize: Appearance.font.pixelSize.normal
                buttonRadius: Appearance.rounding.full
                colText: Appearance.colors.colOnSecondaryContainer
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.trySidebar()
            }

            RippleButtonWithIcon {
                implicitWidth: Appearance.rounding.verylarge * 4
                implicitHeight: Appearance.rounding.verylarge
                centerContent: true
                materialIcon: "search"
                mainText: Translation.tr("Search")
                textPixelSize: Appearance.font.pixelSize.smaller
                iconPixelSize: Appearance.font.pixelSize.normal
                buttonRadius: Appearance.rounding.full
                colText: Appearance.colors.colOnSecondaryContainer
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.trySearch()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: "tune"
                    shape: MaterialShape.Shape.Cookie7Sided
                    iconSize: Appearance.font.pixelSize.large
                    padding: Appearance.rounding.verysmall
                    fill: 1
                    color: Appearance.colors.colSecondaryContainer
                    colSymbol: Appearance.colors.colOnSecondaryContainer
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Quick preferences")
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.variableAxes: Appearance.font.variableAxes.titleRounded
                        font.weight: Font.Bold
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.compactWidth ? 1 : 2
                columnSpacing: Appearance.rounding.normal
                rowSpacing: Appearance.rounding.small

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    spacing: Appearance.rounding.verysmall

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Bar position")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        currentValue: root.barPosition
                        onSelected: newValue => ShellModePolicy.setBarPosition(newValue)
                        options: [{
                            displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0
                        }, {
                            displayName: Translation.tr("Left"), icon: "arrow_back", value: 2,
                            enabled: !ShellModePolicy.barPositionLocked
                        }, {
                            displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1,
                            enabled: !ShellModePolicy.barPositionLocked
                        }, {
                            displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3,
                            enabled: !ShellModePolicy.barPositionLocked
                        }]
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    spacing: Appearance.rounding.verysmall

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Corner style")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        currentValue: Config.options.bar.cornerStyle
                        onSelected: value => Config.options.bar.cornerStyle = value
                        options: [{
                            displayName: Translation.tr("Hug"), icon: "line_curve", value: 0
                        }, {
                            displayName: Translation.tr("Float"), icon: "open_in_full", value: 1
                        }, {
                            displayName: Translation.tr("Rect"), icon: "rectangle", value: 2,
                            enabled: !root.cornerStyleRestricted,
                            tooltip: Translation.tr("Unavailable with Islands background")
                        }, {
                            displayName: Translation.tr("Dynamic Island"), icon: "water_drop", value: 3,
                            enabled: !root.cornerStyleRestricted,
                            tooltip: Translation.tr("Unavailable with Islands background")
                        }]
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Interface extras")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                WelcomeQuickToggle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    Layout.minimumHeight: Appearance.rounding.verylarge + Appearance.rounding.small
                    Layout.preferredHeight: Appearance.rounding.verylarge + Appearance.rounding.small
                    toggleIcon: "dock_to_bottom"
                    label: Translation.tr("Show dock")
                    checked: Config.options.dock.enable
                    onToggleRequested: value => Config.options.dock.enable = value
                }

                WelcomeQuickToggle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    Layout.minimumHeight: Appearance.rounding.verylarge + Appearance.rounding.small
                    Layout.preferredHeight: Appearance.rounding.verylarge + Appearance.rounding.small
                    toggleIcon: "search"
                    label: Translation.tr("Search suggestions")
                    checked: Config.options.search.suggestions.enable
                    onToggleRequested: value => Config.options.search.suggestions.enable = value
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: ShellModePolicy.barPositionLocked || root.cornerStyleRestricted
                text: ShellModePolicy.barPositionLocked
                    ? Translation.tr(ShellModePolicy.barPositionLockedReasonKey)
                    : Translation.tr("Some corner styles are unavailable with the current bar background.")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
