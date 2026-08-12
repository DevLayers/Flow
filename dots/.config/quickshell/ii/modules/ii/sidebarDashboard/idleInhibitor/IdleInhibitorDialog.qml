import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundWidth: 400

    readonly property var options: Config.options.idle

    // Value dialled in on the stepper. Starting it adds it to the chips above,
    // so a duration only has to be dialled once.
    property int customMinutes: 45

    component StepButton: RippleButton {
        id: stepButton
        property string buttonIcon

        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: stepButton.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
            color: stepButton.enabled ? Appearance.colors.colOnLayer2 : Appearance.m3colors.m3outline
        }
    }

    WindowDialogTitle {
        text: Translation.tr("Keep awake")
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        text: Translation.tr("Stops the screen from blanking and the system from sleeping. Pick a duration and it turns itself back off when the time is up.")
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: statusRow.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Idle.inhibit ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        RowLayout {
            id: statusRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 10

            MaterialSymbol {
                text: Idle.inhibit ? "kettle" : "coffee"
                iconSize: Appearance.font.pixelSize.hugeass
                fill: Idle.inhibit ? 1 : 0
                color: Idle.inhibit ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Idle.timed ? Translation.tr("%1 left").arg(Idle.remainingText) : Idle.inhibit ? Translation.tr("On indefinitely") : Translation.tr("Off")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Idle.inhibit ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Idle.timed ? Translation.tr("Sleep resumes automatically") : Idle.inhibit ? Translation.tr("Stays awake until you turn it off") : Translation.tr("The system sleeps as usual")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Idle.inhibit ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Duration")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    FlowButtonGroup {
        Layout.fillWidth: true
        Layout.topMargin: -12
        spacing: 4

        Repeater {
            model: Idle.quickDurations

            delegate: SelectionGroupButton {
                required property int index
                required property var modelData
                leftmost: index === 0
                // Indefinite isn't offered here — that's what plain clicking the toggle does
                rightmost: index === Idle.quickDurations.length - 1
                buttonText: Idle.formatMinutes(modelData)
                toggled: Idle.timed && Idle.sessionMinutes === modelData
                onClicked: Idle.inhibitFor(modelData)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer2

            StepButton {
                anchors {
                    left: parent.left
                    leftMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                buttonIcon: "remove"
                enabled: root.customMinutes > 5
                onClicked: root.customMinutes = Idle.stepMinutes(root.customMinutes, -1)
            }

            StyledText {
                anchors.centerIn: parent
                text: Idle.formatMinutes(root.customMinutes)
                color: Appearance.colors.colOnLayer2
            }

            StepButton {
                anchors {
                    right: parent.right
                    rightMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                buttonIcon: "add"
                enabled: root.customMinutes < 1440
                onClicked: root.customMinutes = Idle.stepMinutes(root.customMinutes, 1)
            }
        }

        DialogButton {
            buttonText: Translation.tr("Start")
            onClicked: Idle.inhibitFor(root.customMinutes)
        }
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        Layout.topMargin: 4

        readonly property string leadText: Idle.warnLeadSec >= 60 ? Idle.formatMinutes(Math.round(Idle.warnLeadSec / 60)) : Translation.tr("%1 s").arg(Idle.warnLeadSec)

        text: Idle.notifyOnExpiry && Idle.warnLeadSec > 0 ? Translation.tr("You'll get a notification %1 before it ends, with a button to add %2.").arg(leadText).arg(Idle.formatMinutes(Idle.extendMinutes)) : Translation.tr("Expiry notifications are off — see Settings › Power.")
    }

    WindowDialogButtonRow {
        Layout.fillWidth: true

        DialogButton {
            buttonText: Translation.tr("Extend %1").arg(Idle.formatMinutes(Idle.extendMinutes))
            enabled: Idle.timed
            colText: enabled ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
            onClicked: Idle.extendBy(Idle.extendMinutes)
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Turn off")
            enabled: Idle.inhibit
            colText: enabled ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
            onClicked: Idle.toggleInhibit(false)
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
