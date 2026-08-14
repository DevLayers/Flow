import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.welcome
import qs.modules.welcome.tutorials
import "."

Item {
    id: root

    property string stepNumber: "1"
    property string stateKind: "pending" // "complete", "current", "pending", "error"
    property string title: ""
    property string supportingText: ""
    property bool isLast: false
    default property alias stepContent: customContentSlot.data

    Layout.fillWidth: true
    implicitHeight: mainRow.implicitHeight + 16

    readonly property color markerBg: {
        if (root.stateKind === "complete")
            return Appearance.colors.colPrimary;
        if (root.stateKind === "current")
            return Appearance.colors.colPrimaryContainer;
        if (root.stateKind === "error")
            return Appearance.colors.colError;
        return Appearance.colors.colLayer2;
    }

    readonly property color markerFg: {
        if (root.stateKind === "complete")
            return Appearance.colors.colOnPrimary;
        if (root.stateKind === "current")
            return Appearance.colors.colOnPrimaryContainer;
        if (root.stateKind === "error")
            return Appearance.colors.colOnError;
        return Appearance.colors.colOnLayer2;
    }

    RowLayout {
        id: mainRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 16

        // Left Timeline Column
        Item {
            Layout.preferredWidth: 32
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop

            // Vertical Connecting Line
            Rectangle {
                visible: !root.isLast
                anchors.top: markerCircle.bottom
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2
                color: Appearance.colors.colLayer2
            }

            // Step Marker Circle
            Rectangle {
                id: markerCircle
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                height: 28
                radius: 14
                color: root.markerBg

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: root.stateKind === "complete" || root.stateKind === "error"
                    text: root.stateKind === "complete" ? "check" : "priority_high"
                    iconSize: 16
                    color: root.markerFg
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.stateKind !== "complete" && root.stateKind !== "error"
                    text: root.stepNumber
                    color: root.markerFg
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }
            }
        }

        // Right Content Column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.supportingText.length > 0
                text: root.supportingText
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                id: customContentSlot
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
            }
        }
    }
}
