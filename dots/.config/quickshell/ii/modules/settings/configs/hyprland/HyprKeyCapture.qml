pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Choose the key a shortcut sits on, by pressing it or by typing its name.
 *
 * Capture alone is not enough on a layout that is not US. Qt reports the character the key
 * produces, and on this machine's AZERTY the digits never arrive unshifted at all, so a naive
 * capture writes a shortcut that does not match what Hyprland sees. Three things follow from
 * that: what was captured is always shown as text before it is saved, the text is editable, and
 * a key whose meaning moves with the layout can be written as the physical key instead
 * (`code:38`), which is the same key on every layout.
 */
ColumnLayout {
    id: root

    property var mods: []
    property string key: ""
    property bool capturing: false
    /// The last physical key seen, so "use the physical key" can be offered after the fact.
    property int lastScanCode: 0

    signal chosen(var newMods, string newKey)

    spacing: 8

    /// Qt key codes that mean the same thing on every layout. Letters and digits are handled
    /// separately: those are the ones a layout moves around.
    readonly property var namedKeys: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "Space",
        [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home",
        [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause", [Qt.Key_Menu]: "Menu",
        [Qt.Key_ScrollLock]: "Scroll_Lock",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MediaPlay]: "XF86AudioPlay",
        [Qt.Key_MediaStop]: "XF86AudioStop", [Qt.Key_MediaNext]: "XF86AudioNext",
        [Qt.Key_MediaPrevious]: "XF86AudioPrev",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
        [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
    })

    /// The character a key produced, as XKB names it. Only for the punctuation people really
    /// bind; anything else falls back to the physical key.
    readonly property var characterKeys: ({
        "/": "Slash", ".": "Period", ",": "Comma", ";": "Semicolon", "'": "Apostrophe",
        "-": "Minus", "=": "Equal", "[": "bracketleft", "]": "bracketright",
        "\\": "Backslash", "`": "grave", ":": "colon", "*": "asterisk", "+": "plus",
        "<": "less", ">": "greater", "!": "exclam", "?": "question", "&": "ampersand",
        "$": "dollar", "#": "numbersign", "@": "at", "%": "percent", "^": "asciicircum",
        "~": "asciitilde", "_": "underscore", "\"": "quotedbl"
    })

    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta,
        Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_Super_L, Qt.Key_Super_R]

    function modsFromEvent(modifiers: int): var {
        const out = [];
        if (modifiers & Qt.ControlModifier) out.push("CTRL");
        if (modifiers & Qt.MetaModifier) out.push("SUPER");
        if (modifiers & Qt.AltModifier) out.push("ALT");
        if (modifiers & Qt.ShiftModifier) out.push("SHIFT");
        return HyprlandBinds.sortMods(out);
    }

    function keyNameFor(event: var): string {
        if (root.namedKeys[event.key] !== undefined) return root.namedKeys[event.key];
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35)
            return `F${event.key - Qt.Key_F1 + 1}`;
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode(event.key);
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            return String.fromCharCode(event.key);
        const text = String(event.text ?? "");
        if (root.characterKeys[text] !== undefined) return root.characterKeys[text];
        if (/^[a-zA-Z]$/.test(text)) return text.toUpperCase();
        if (/^[0-9]$/.test(text)) return text;
        // Nothing readable came through, which is exactly the case the physical key is for.
        return event.nativeScanCode > 0 ? `code:${event.nativeScanCode}` : "";
    }

    /// Reports outwards and nothing else. `mods` and `key` stay bound to whatever the page
    /// holds, so assigning them here would break that binding on the first capture and leave
    /// the field showing a value the page has since moved on from.
    function apply(newMods: var, newKey: string) {
        root.chosen(newMods, newKey);
    }

    function usePhysicalKey() {
        if (root.lastScanCode <= 0) return;
        root.apply(root.mods, `code:${root.lastScanCode}`);
    }

    readonly property bool isPhysical: /^code:\d+$/.test(root.key)

    RippleButton {
        id: captureButton
        Layout.fillWidth: true
        implicitHeight: 68
        buttonRadius: Appearance.rounding.normal
        colBackground: root.capturing ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
        colBackgroundHover: root.capturing ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colLayer2Hover
        colRipple: root.capturing ? Appearance.colors.colPrimaryContainerActive
            : Appearance.colors.colLayer2Active

        onClicked: {
            root.capturing = !root.capturing;
            if (root.capturing) captureButton.forceActiveFocus();
        }

        // Losing focus while armed leaves a button that looks like it is listening and is not.
        onActiveFocusChanged: {
            if (!captureButton.activeFocus) root.capturing = false;
        }

        Keys.onPressed: event => {
            if (!root.capturing) return;
            event.accepted = true;
            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Escape) {
                root.capturing = false;
                return;
            }
            if (root.modifierKeys.includes(event.key)) return;
            root.lastScanCode = event.nativeScanCode ?? 0;
            const name = root.keyNameFor(event);
            if (name === "") return;
            root.apply(root.modsFromEvent(event.modifiers), name);
            root.capturing = false;
        }

        // Wrapped in a plain Item, the way every other button on this page is: a Control
        // positions its contentItem itself, and a layout anchored straight into that fights it.
        contentItem: Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Flow {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.capturing && root.key !== ""
                    spacing: 4

                    Repeater {
                        model: root.mods

                        delegate: HyprKeyChip {
                            required property var modelData

                            subdued: true
                            text: HyprlandBinds.modLabels[modelData] ?? modelData
                        }
                    }

                    HyprKeyChip {
                        text: HyprlandBinds.keyLabel(root.key)
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.capturing ? Translation.tr("Press the shortcut now — Esc to stop")
                        : (root.key === "" ? Translation.tr("Click, then press the shortcut")
                            : Translation.tr("Click to record a different one"))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.capturing ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colSubtext
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ConfigTextField {
            id: manualField
            Layout.fillWidth: true
            placeholderText: Translation.tr("SUPER + SHIFT + A")

            readonly property string currentValue: HyprlandBinds.comboSource(root.mods, root.key)

            onCurrentValueChanged: {
                if (manualField.textField.activeFocus) return;
                manualField.inputText = manualField.currentValue;
            }

            Component.onCompleted: manualField.inputText = manualField.currentValue

            Connections {
                target: manualField.textField

                function onEditingFinished() {
                    if (manualField.inputText === manualField.currentValue) return;
                    const parts = HyprlandBinds.splitCombo(manualField.inputText);
                    root.apply(parts.mods, parts.key);
                }
            }
        }

        RippleButton {
            visible: root.lastScanCode > 0 && !root.isPhysical
            implicitHeight: 40
            implicitWidth: physicalLabel.implicitWidth + 24
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            onClicked: root.usePhysicalKey()

            StyledText {
                id: physicalLabel
                anchors.centerIn: parent
                text: Translation.tr("Use the physical key")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: root.isPhysical
            ? Translation.tr("This is the key in that position on the keyboard, whatever it prints. It keeps working if you change layout.")
            : Translation.tr("This is the character the key produces, so it moves if you change keyboard layout. Digits and punctuation are the ones that move most.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.WordWrap
    }
}
