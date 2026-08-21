pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

/**
 * A small, local Settings control backed by one generated index entry.
 *
 * This is deliberately useful without a model: callers hand it a SettingRef
 * from AiSettingsIntegration and it validates every direct write with the
 * same strict path used by the approved AI diff.
 */
Rectangle {
    id: root

    required property var setting
    property bool compact: false
    property var currentValue: root.readCurrentValue()
    property string writeError: ""

    readonly property string key: String(root.setting?.key ?? "")
    readonly property string settingType: String(root.setting?.type ?? "")
    readonly property var range: root.setting?.range ?? ({})
    readonly property var enumOptions: Array.from(root.setting?.options ?? []).map(option => ({
                displayName: String(option?.label ?? option?.value ?? ""),
                value: option?.value
            }))
    readonly property bool hasRange: root.range?.from !== undefined && root.range?.from !== null
        && root.range?.to !== undefined && root.range?.to !== null
    readonly property string displayLabel: String(root.setting?.labelLocalized ?? root.setting?.label ?? root.key)
    readonly property string sectionPath: [
        root.setting?.pageNameLocalized ?? root.setting?.pageName ?? "",
        root.setting?.sectionTitleLocalized ?? root.setting?.sectionTitle ?? ""
    ].filter(part => String(part).length > 0).join(" › ")

    function readCurrentValue(): var {
        if (root.key.length === 0)
            return undefined;
        return Config.getNestedValue(Config.options, root.key.split("."));
    }

    function writeValue(value: var): bool {
        if (root.key.length === 0)
            return false;
        const verdict = Ai.settingsIntegration.validate(root.key, value);
        if (!verdict.ok) {
            root.writeError = String(verdict.reason ?? Translation.tr("This value is not valid for this setting."));
            return false;
        }
        try {
            root.currentValue = Config.setNestedValue(root.key, value, true);
            root.writeError = "";
            return true;
        } catch (error) {
            root.writeError = String(error);
            return false;
        }
    }

    function openInSettings() {
        GlobalStates.openSettingsPage(
                    String(root.setting?.pageId ?? ""),
                    String(root.setting?.subPage ?? ""),
                    String(root.setting?.sectionTitleLocalized ?? root.setting?.sectionTitle ?? ""));
    }

    function explain() {
        const description = String(root.setting?.descriptionLocalized ?? root.setting?.description ?? "");
        const prompt = Translation.tr("Explain the setting %1 (%2). %3").arg(root.displayLabel).arg(root.key).arg(description);
        Ai.sendUserMessage(prompt);
    }

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + (root.compact ? 16 : 20)
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: root.compact ? 8 : 10
        spacing: root.compact ? 4 : 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: String(root.setting?.icon ?? "tune")
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayLabel
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.sectionPath.length > 0
                    text: root.sectionPath
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButton {
                implicitWidth: 34
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.openInSettings()

                Accessible.name: Translation.tr("Open in Settings")

                contentItem: MaterialSymbol {
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                }

                StyledToolTip { text: Translation.tr("Open in Settings") }
            }
        }

        Loader {
            id: controlLoader
            Layout.fillWidth: true
            sourceComponent: {
                if (root.settingType === "bool")
                    return switchControl;
                if (root.settingType === "int")
                    return integerControl;
                if (root.settingType === "real" && root.hasRange)
                    return realControl;
                if (root.settingType === "enum" && root.enumOptions.length > 0)
                    return enumControl;
                if (root.settingType === "string")
                    return textControl;
                return null;
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: controlLoader.item === null
            text: Translation.tr("Open this setting to change its value.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.writeError.length > 0
            text: root.writeError
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colError
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.compact
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: root.key
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                implicitHeight: 28
                leftPadding: 10
                rightPadding: 10
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.explain()

                contentItem: StyledText {
                    text: Translation.tr("Explain")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }
    }

    Component {
        id: switchControl

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            StyledSwitch {
                checked: Boolean(root.currentValue)
                onToggled: root.writeValue(checked)
            }
        }
    }

    Component {
        id: integerControl

        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            StyledSpinBox {
                from: root.hasRange ? Number(root.range.from) : -1000000
                to: root.hasRange ? Number(root.range.to) : 1000000
                stepSize: Number(root.range?.step ?? 1)
                value: Number(root.currentValue ?? 0)
                onValueModified: root.writeValue(value)
            }
        }
    }

    Component {
        id: realControl

        StyledSlider {
            Layout.fillWidth: true
            from: Number(root.range.from)
            to: Number(root.range.to)
            stepSize: Number(root.range?.step ?? 0)
            value: Number(root.currentValue ?? root.range.from)
            usePercentTooltip: false
            onMoved: root.writeValue(value)
        }
    }

    Component {
        id: enumControl

        ConfigSelectionArray {
            Layout.fillWidth: true
            options: root.enumOptions
            currentValue: root.currentValue
            onSelected: value => root.writeValue(value)
        }
    }

    Component {
        id: textControl

        MaterialTextField {
            Layout.fillWidth: true
            text: String(root.currentValue ?? "")
            onEditingFinished: root.writeValue(text)
        }
    }
}
