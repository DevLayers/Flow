pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
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
    // The launcher presents settings beside program rows, while chat uses a
    // calmer layer card. Keep both surfaces in this shared control without
    // giving the launcher an unframed, visually floating result.
    property bool launcherStyle: false
    // SearchItem's grouped radius is based on these ListView positions. The
    // card is also used in chat, where they intentionally remain unset.
    property int listIndex: -1
    property int listCount: 0
    property int listCurrentIndex: -1
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
    readonly property bool isFirst: root.listIndex === 0 && root.listCount > 0
    readonly property bool isLast: root.listIndex >= 0 && root.listIndex === root.listCount - 1
    readonly property bool isSelected: root.listIndex >= 0 && root.listIndex === root.listCurrentIndex
    readonly property bool isAboveSelected: root.listIndex >= 0 && root.listCurrentIndex === root.listIndex + 1
    readonly property bool isBelowSelected: root.listIndex >= 0 && root.listCurrentIndex === root.listIndex - 1
    readonly property real pillRadius: Math.min(root.height / 2, Appearance.rounding.large)
    readonly property bool supportsHorizontalNavigation: root.settingType === "bool"
        || root.settingType === "int"
        || root.settingType === "real"
        || (root.settingType === "enum" && root.enumOptions.length > 0)
    readonly property color foregroundColor: root.launcherStyle && root.isSelected
        ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
    readonly property color secondaryColor: root.launcherStyle && root.isSelected
        ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
    readonly property bool isHovered: cardHover.hovered
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

    function numericStep(): real {
        const configured = Number(root.range?.step ?? 0);
        if (isFinite(configured) && configured > 0)
            return configured;
        if (root.settingType === "real" && root.hasRange) {
            const span = Math.abs(Number(root.range.to) - Number(root.range.from));
            if (isFinite(span) && span > 0)
                return span / 100;
        }
        return 1;
    }

    function boundedNumericValue(value: real): real {
        let result = Number(value);
        if (!isFinite(result))
            result = Number(root.currentValue ?? 0);
        if (root.hasRange)
            result = Math.max(Number(root.range.from), Math.min(Number(root.range.to), result));
        return root.settingType === "int" ? Math.round(result) : result;
    }

    /** Applies one horizontal keyboard move without giving the control focus. */
    function adjustBy(direction: int): bool {
        const stepDirection = direction < 0 ? -1 : (direction > 0 ? 1 : 0);
        if (stepDirection === 0)
            return false;

        if (root.settingType === "bool") {
            const wanted = stepDirection > 0;
            return Boolean(root.currentValue) === wanted ? false : root.writeValue(wanted);
        }

        if (root.settingType === "int" || root.settingType === "real") {
            const next = root.boundedNumericValue(Number(root.currentValue ?? 0) + root.numericStep() * stepDirection);
            return Number(root.currentValue) === next ? false : root.writeValue(next);
        }

        if (root.settingType === "enum" && root.enumOptions.length > 0) {
            let index = root.enumOptions.findIndex(option => option.value === root.currentValue);
            if (index < 0)
                index = stepDirection > 0 ? -1 : root.enumOptions.length;
            const nextIndex = Math.max(0, Math.min(root.enumOptions.length - 1, index + stepDirection));
            return nextIndex === index ? false : root.writeValue(root.enumOptions[nextIndex].value);
        }

        return false;
    }

    function openInSettings() {
        GlobalStates.openSettingsPage(
                    String(root.setting?.pageId ?? ""),
                    String(root.setting?.subPage ?? ""),
                    String(root.setting?.sectionTitleLocalized ?? root.setting?.sectionTitle ?? ""));
    }

    /**
     * The action for Enter on a selected launcher result. Toggles change in
     * place; a text field takes keyboard focus; the remaining controls are
     * adjusted with Left/Right and open their source on Enter.
     */
    function activate(): bool {
        if (root.settingType === "bool")
            return root.writeValue(!Boolean(root.currentValue));
        if (root.settingType === "string" && controlLoader.item) {
            controlLoader.item.forceActiveFocus();
            return true;
        }
        root.openInSettings();
        return true;
    }

    function clicked(): bool {
        return root.activate();
    }

    function navigateLeft(): bool {
        return root.adjustBy(-1);
    }

    function navigateRight(): bool {
        return root.adjustBy(1);
    }

    function explain() {
        const description = String(root.setting?.descriptionLocalized ?? root.setting?.description ?? "");
        const prompt = Translation.tr("Explain the setting %1 (%2). %3").arg(root.displayLabel).arg(root.key).arg(description);
        Ai.sendUserMessage(prompt);
    }

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + (root.compact ? 16 : 20)
    radius: Appearance.rounding.normal
    topLeftRadius: root.launcherStyle
        ? (root.isFirst ? Appearance.rounding.large : (root.isSelected || root.isBelowSelected ? root.pillRadius : Appearance.rounding.small))
        : Appearance.rounding.normal
    topRightRadius: root.topLeftRadius
    bottomLeftRadius: root.launcherStyle
        ? (root.isLast ? Appearance.rounding.large : (root.isSelected || root.isAboveSelected ? root.pillRadius : Appearance.rounding.small))
        : Appearance.rounding.normal
    bottomRightRadius: root.bottomLeftRadius
    color: root.launcherStyle
        ? (root.isSelected ? Appearance.colors.colPrimary : (root.isHovered ? Appearance.colors.colSurfaceContainerHighHover : Appearance.colors.colSurfaceContainerHigh))
        : Appearance.colors.colLayer2

    // The full card gets a neutral surface hover. Its state must stay
    // separate from a checked switch, which uses the primary color.
    HoverHandler {
        id: cardHover
    }

    Behavior on topLeftRadius {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on bottomLeftRadius {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
        }
    }

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
                color: root.foregroundColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayLabel
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.foregroundColor
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.sectionPath.length > 0
                    text: root.sectionPath
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.secondaryColor
                    opacity: root.launcherStyle && root.isSelected ? 0.78 : 1
                }
            }

            RippleButton {
                implicitWidth: 34
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(root.isSelected ? Appearance.colors.colPrimary : Appearance.colors.colLayer2, 1)
                colBackgroundHover: root.isSelected ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                colRipple: root.isSelected ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active
                onClicked: root.openInSettings()

                Accessible.name: Translation.tr("Open in Settings")

                contentItem: MaterialSymbol {
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.small
                    color: root.foregroundColor
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
