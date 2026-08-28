pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Input -> Advanced keyboard.
 *
 * XKB quirks and multi-layout setup: things almost nobody touches after the first time they set
 * them up, which is why they live behind a tap rather than sitting open on the Input tab for
 * every visit.
 */
Item {
    id: subPageRoot
    anchors.fill: parent

    signal goBack
    property bool showBackButton: false

    ContentPage {
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Translation.tr("Advanced keyboard")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("XKB quirks and multiple layouts at once")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        ContentSection {
            title: Translation.tr("Key behaviour")
            icon: "keyboard_option_key"

            HyprXkbOptionSwitch {
                option: "caps:escape"
                buttonIcon: "keyboard_capslock"
                text: Translation.tr("Caps Lock acts as Escape")
            }

            HyprXkbOptionSwitch {
                option: "caps:swapescape"
                buttonIcon: "swap_horiz"
                text: Translation.tr("Swap Caps Lock and Escape")
            }

            HyprXkbOptionSwitch {
                option: "compose:ralt"
                buttonIcon: "add_circle"
                text: Translation.tr("Right Alt is the Compose key")

                StyledToolTip {
                    text: Translation.tr("Compose then ' then e types é. Works in every app, without a layout that has the letter on it.")
                }
            }

            HyprXkbOptionSwitch {
                option: "terminate:ctrl_alt_bksp"
                buttonIcon: "logout"
                text: Translation.tr("Ctrl+Alt+Backspace kills the session")
            }

            HyprXkbOptionSwitch {
                option: "grp:alt_shift_toggle"
                buttonIcon: "language"
                text: Translation.tr("Alt+Shift switches between layouts")
            }

            HyprSwitch {
                optionKey: "input:resolve_binds_by_sym"
                buttonIcon: "abc"
                text: Translation.tr("Match shortcuts by symbol, not position")

                StyledToolTip {
                    text: Translation.tr("On an AZERTY layout, SUPER+A then means the key that types A rather than the key where A sits on QWERTY.")
                }
            }
        }

        ContentSection {
            title: Translation.tr("Several layouts at once")
            icon: "list"

            HyprTextField {
                optionKey: "input:kb_layout"
                defaultValue: "us"
                icon: "language"
                text: Translation.tr("Layout codes")
                placeholderText: "fr,us"
                tooltip: Translation.tr("Comma separated. The first one is active at startup.")
            }

            HyprTextField {
                optionKey: "input:kb_variant"
                icon: "tune"
                text: Translation.tr("Variants")
                placeholderText: ",intl"
                tooltip: Translation.tr("One per layout, in the same order. Leave a slot empty for no variant.")
            }

            HyprTextField {
                optionKey: "input:kb_options"
                icon: "settings"
                text: Translation.tr("XKB options")
                placeholderText: "caps:escape,compose:ralt"
                tooltip: Translation.tr("The raw list. The switches above edit the same string.")
            }

            HyprTextField {
                optionKey: "input:kb_model"
                icon: "keyboard_alt"
                text: Translation.tr("Keyboard model")
                placeholderText: "pc105"
            }

            HyprOptionNote {
                keys: ["input:kb_layout", "input:kb_variant", "input:kb_options", "input:kb_model",
                    "input:resolve_binds_by_sym"]
            }
        }
    }
}
