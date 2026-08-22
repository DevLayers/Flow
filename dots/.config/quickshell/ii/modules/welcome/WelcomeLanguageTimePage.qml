import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal backRequested()

    readonly property var languageOptions: [
        {
            displayName: Translation.tr("Auto (System)"),
            value: "auto"
        },
        ...Translation.allAvailableLanguages.map(lang => {
            return {
                displayName: lang,
                value: lang
            };
        })
    ]

    readonly property var clockFormatOptions: [
        {
            displayName: Translation.tr("24h"),
            value: "hh:mm"
        },
        {
            displayName: Translation.tr("12h am/pm"),
            value: "h:mm ap"
        },
        {
            displayName: Translation.tr("12h AM/PM"),
            value: "h:mm AP"
        }
    ]

    readonly property var dateFormatOptions: [
        {
            displayName: Translation.tr("Day first · dd/MM"),
            value: "dd/MM, ddd"
        },
        {
            displayName: Translation.tr("Month first · MM/dd"),
            value: "MM/dd, ddd"
        }
    ]

    function selectedIndex(options, value): int {
        const index = options.findIndex(option => option.value === value);
        return index >= 0 ? index : 0;
    }

    function goBack(): void {
        root.backRequested();
    }

    function closeNestedPage(): bool {
        return false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.rounding.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            RippleButton {
                Layout.preferredWidth: Appearance.rounding.verylarge
                Layout.preferredHeight: Appearance.rounding.verylarge
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                colRipple: Appearance.colors.colSecondaryContainerActive
                Accessible.name: Translation.tr("Back to essentials")
                onClicked: root.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.verysmall

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Language & Time")
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.variableAxes: Appearance.font.variableAxes.titleRounded
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Set the basics now. You can fine-tune everything later in Settings.")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.normal
                    wrapMode: Text.WordWrap
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            title: Translation.tr("Interface language")
            icon: "language"

            StyledComboBox {
                id: languageSelector
                Layout.fillWidth: true
                buttonIcon: "translate"
                textRole: "displayName"
                model: root.languageOptions
                currentIndex: root.selectedIndex(root.languageOptions, Config.options.language.ui)
                onActivated: index => {
                    const option = model[index];
                    if (option)
                        Config.options.language.ui = option.value;
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            title: Translation.tr("Time & date")
            icon: "schedule"

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 620 ? 2 : 1
                columnSpacing: Appearance.rounding.small
                rowSpacing: Appearance.rounding.verysmall

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "pace"
                    text: Translation.tr("Second precision")
                    checked: Config.options.time.secondPrecision
                    onCheckedChanged: Config.options.time.secondPrecision = checked
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "avg_pace"
                    text: Translation.tr("Show seconds on the bar clock")
                    checked: Config.options.bar.clock.showSeconds
                    onCheckedChanged: Config.options.bar.clock.showSeconds = checked
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "today"
                    text: Translation.tr("Start week on Monday")
                    checked: Config.options.time.firstDayOfWeek === 0
                    onCheckedChanged: Config.options.time.firstDayOfWeek = checked ? 0 : 6
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 620 ? 2 : 1
                columnSpacing: Appearance.rounding.small
                rowSpacing: Appearance.rounding.verysmall

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.rounding.verysmall

                    ContentSubsectionLabel {
                        text: Translation.tr("Clock format")
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "schedule"
                        textRole: "displayName"
                        model: root.clockFormatOptions
                        currentIndex: root.selectedIndex(root.clockFormatOptions, Config.options.time.format)
                        onActivated: index => {
                            const option = model[index];
                            if (!option)
                                return;
                            DateUtils.syncHyprlockTimeFormat(option.value);
                            Config.options.time.format = option.value;
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.rounding.verysmall

                    ContentSubsectionLabel {
                        text: Translation.tr("Date format")
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "date_range"
                        textRole: "displayName"
                        model: root.dateFormatOptions
                        currentIndex: root.selectedIndex(root.dateFormatOptions, Config.options.time.dateFormat)
                        onActivated: index => {
                            const option = model[index];
                            if (option)
                                Config.options.time.dateFormat = option.value;
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
