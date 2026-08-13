import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

Item {
    id: root

    WPanelPageColumn {
        anchors.fill: parent

        BodyRectangle {
            implicitHeight: 400
            implicitWidth: 50

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                HeaderRow {
                    id: headerRow
                    Layout.fillWidth: true
                    title: Translation.tr("Keep awake")
                }

                StyledFlickable {
                    id: flickable
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    contentHeight: contentLayout.implicitHeight
                    contentWidth: width
                    clip: true

                    bottomMargin: 12

                    IdleOptions {
                        id: contentLayout
                        width: flickable.width
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {}
    }

    component IdleOptions: ColumnLayout {
        id: idleOptions
        spacing: 10

        // Value dialled in on the stepper. Starting it adds it to the buttons above,
        // so a duration only has to be dialled once.
        property int customMinutes: 45

        ToggleItem {
            name: Translation.tr("Keep awake")
            description: Idle.timed ? Translation.tr("%1 left").arg(Idle.remainingText) : Idle.inhibit ? Translation.tr("Stays awake until you turn it off") : Translation.tr("The system sleeps as usual")
            iconName: "drink-coffee"
            checked: Idle.inhibit
            onCheckedChanged: {
                if (checked === Idle.inhibit) return;
                Idle.toggleInhibit(checked);
            }
        }

        SectionText {
            text: Translation.tr("Turn off automatically after")
        }

        Repeater {
            model: Idle.quickDurations

            delegate: WChoiceButton {
                required property var modelData
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: Idle.formatMinutes(modelData)
                checked: Idle.timed && Idle.sessionMinutes === modelData
                onClicked: Idle.inhibitFor(modelData)
            }
        }

        WChoiceButton {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            text: Translation.tr("Don't turn off")
            icon.name: "weather-moon-off"
            checked: Idle.inhibit && !Idle.timed
            onClicked: Idle.toggleInhibit(true)
        }

        SectionText {
            text: Translation.tr("Custom duration")
        }

        RowLayout {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.fillWidth: true
            spacing: 2

            WPanelIconButton {
                iconName: "subtract"
                enabled: idleOptions.customMinutes > 5
                onClicked: idleOptions.customMinutes = Idle.stepMinutes(idleOptions.customMinutes, -1)
            }

            WText {
                Layout.minimumWidth: 70
                horizontalAlignment: Text.AlignHCenter
                text: Idle.formatMinutes(idleOptions.customMinutes)
            }

            WPanelIconButton {
                iconName: "add"
                enabled: idleOptions.customMinutes < 1440
                onClicked: idleOptions.customMinutes = Idle.stepMinutes(idleOptions.customMinutes, 1)
            }

            Item {
                Layout.fillWidth: true
            }

            WTextButton {
                text: Translation.tr("Start")
                onClicked: Idle.inhibitFor(idleOptions.customMinutes)
            }
        }

        SectionText {
            text: Translation.tr("Running session")
        }

        WChoiceButton {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            enabled: Idle.timed
            text: Translation.tr("Add %1").arg(Idle.formatMinutes(Idle.extendMinutes))
            icon.name: "add"
            onClicked: Idle.extendBy(Idle.extendMinutes)
        }
    }
}
