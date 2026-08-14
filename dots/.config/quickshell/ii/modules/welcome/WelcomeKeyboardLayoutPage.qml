import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal backRequested()

    property bool statusIsError: false
    property string statusText: ""
    property bool appliedFeedback: false

    Timer {
        id: feedbackTimer
        interval: 2200
        onTriggered: {
            root.appliedFeedback = false;
            root.statusText = "";
        }
    }

    function normalizeValue(value, allowEmpty): string {
        const parts = String(value ?? "").split(",").map(part => part.trim());
        if (!allowEmpty && parts.some(part => part.length === 0))
            return "";

        for (const part of parts) {
            if (!/^[A-Za-z0-9_-]*$/.test(part))
                return "";
        }
        return parts.join(",");
    }

    function applyKeyboardLayout(): void {
        const layoutValue = root.normalizeValue(layoutField.text, false);
        const variantValue = root.normalizeValue(variantField.text, true);
        if (layoutValue.length === 0) {
            root.statusIsError = true;
            root.statusText = Translation.tr("Enter at least one valid XKB layout code, such as us or br.");
            feedbackTimer.restart();
            return;
        }
        if (variantValue.length === 0 && variantField.text.trim().length > 0) {
            root.statusIsError = true;
            root.statusText = Translation.tr("Use only letters, numbers, underscores and hyphens in variants.");
            feedbackTimer.restart();
            return;
        }

        // `keyword` applies the change immediately to the running Hyprland
        // instance. HyprlandConfig then stores the same values in the managed
        // shell override so the next session keeps the selected layouts.
        Quickshell.execDetached(["hyprctl", "keyword", "input:kb_layout", layoutValue]);
        Quickshell.execDetached(["hyprctl", "keyword", "input:kb_variant", variantValue]);
        HyprlandConfig.setMany({
            "input:kb_layout": layoutValue,
            "input:kb_variant": variantValue
        }, {});

        root.statusIsError = false;
        root.statusText = Translation.tr("Keyboard layouts applied to Hyprland.");
        root.appliedFeedback = true;
        feedbackTimer.restart();
    }

    function switchKeyboardLayout(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
        root.statusIsError = false;
        root.statusText = Translation.tr("Switched to the next keyboard layout.");
        feedbackTimer.restart();
    }

    function syncFields(): void {
        if (!layoutField.activeFocus)
            layoutField.text = HyprlandXkb.layoutCodes.join(",");
        if (!variantField.activeFocus)
            variantField.text = HyprlandXkb.layoutVariants.join(",");
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
                onClicked: root.backRequested()

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
                    text: Translation.tr("Keyboard layout")
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.variableAxes: Appearance.font.variableAxes.titleRounded
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Add layouts and variants directly to Hyprland.")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.normal
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ContentPage is a full-frame widget. Keep it inside a layout
            // item so its anchors cannot cover the local page header.
            ContentPage {
                anchors.fill: parent
                forceWidth: false
                bottomContentPadding: Appearance.rounding.large

                ContentSection {
                    icon: "keyboard"
                    title: Translation.tr("Keyboard layouts")

                    ContentSubsection {
                        title: Translation.tr("Active layout")
                        icon: "translate"
                        tooltip: Translation.tr("Switch between the layouts configured in Hyprland.")
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.rounding.small

                            StyledText {
                                id: activeLayoutText
                                Layout.fillWidth: true
                                text: HyprlandXkb.currentLayoutCode.length > 0
                                    ? Translation.tr("Current: %1").arg(HyprlandXkb.currentLayoutCode)
                                    : Translation.tr("No active layout reported")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight

                                Behavior on opacity {
                                    enabled: WelcomeMotion.motionEnabled
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }

                            RippleButtonWithIcon {
                                materialIcon: "swap_horiz"
                                mainText: Translation.tr("Switch layout")
                                centerContent: true
                                colText: Appearance.colors.colOnSecondaryContainer
                                colBackground: Appearance.colors.colSecondaryContainer
                                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                                colRipple: Appearance.colors.colSecondaryContainerActive
                                onClicked: root.switchKeyboardLayout()
                            }
                        }
                    }

                    ContentSubsection {
                        title: Translation.tr("Layouts")
                        icon: "language"
                        tooltip: Translation.tr("Comma-separated XKB layout codes, for example us,br.")
                        Layout.fillWidth: true

                        MaterialTextField {
                            id: layoutField
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Layout codes, for example us,br")
                            wrapMode: TextEdit.NoWrap
                            text: HyprlandXkb.layoutCodes.join(",")
                        }
                    }

                    ContentSubsection {
                        title: Translation.tr("Layout variants")
                        icon: "tune"
                        tooltip: Translation.tr("Optional comma-separated XKB variants. Keep empty entries to match a layout, for example ,abnt2.")
                        Layout.fillWidth: true

                        MaterialTextField {
                            id: variantField
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Variants, optional; for example ,abnt2")
                            wrapMode: TextEdit.NoWrap
                            text: HyprlandXkb.layoutVariants.join(",")
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: statusTextLabel.implicitHeight
                        visible: opacity > 0.001
                        opacity: root.statusText.length > 0 ? 1 : 0

                        Behavior on opacity {
                            enabled: WelcomeMotion.motionEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        StyledText {
                            id: statusTextLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: root.statusText
                            color: root.statusIsError
                                ? Appearance.colors.colError
                                : Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                            y: root.statusText.length > 0 ? 0 : 4

                            Behavior on y {
                                enabled: WelcomeMotion.motionEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }
                    }

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: root.appliedFeedback ? "check" : "save"
                        mainText: root.appliedFeedback
                            ? Translation.tr("Applied to Hyprland")
                            : Translation.tr("Apply to Hyprland")
                        centerContent: true
                        colText: Appearance.colors.colOnPrimary
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colBackgroundActive: Appearance.colors.colPrimaryActive
                        colRipple: Appearance.colors.colPrimaryActive
                        onClicked: root.applyKeyboardLayout()
                    }
                }
            }
        }
    }

    Connections {
        target: HyprlandXkb
        function onLayoutCodesChanged() {
            root.syncFields();
        }
        function onLayoutVariantsChanged() {
            root.syncFields();
        }
    }
}
