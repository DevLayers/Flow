pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property date initialDate: new Date()
    property int defaultDurationMinutes: 30
    property string errorText: ""
    property bool busy: false
    signal submitted(var fields)
    signal cancelled()

    implicitHeight: formColumn.implicitHeight

    function normalizedDate(value) {
        const match = String(value ?? "").trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (!match)
            return null;
        const result = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        return isNaN(result.getTime()) ? null : result;
    }

    function normalizedTime(value) {
        return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value ?? "").trim());
    }

    function localIso(dateValue, timeValue) {
        return Qt.formatDate(dateValue, "yyyy-MM-dd") + "T" + timeValue + ":00";
    }

    function reset() {
        const start = root.initialDate instanceof Date && !isNaN(root.initialDate.getTime())
            ? root.initialDate
            : new Date();
        const roundedMinutes = Math.ceil(start.getMinutes() / 15) * 15;
        start.setMinutes(roundedMinutes, 0, 0);
        const end = new Date(start.getTime() + Math.max(1, root.defaultDurationMinutes) * 60000);
        titleField.text = "";
        startDateField.text = Qt.formatDate(start, "yyyy-MM-dd");
        endDateField.text = Qt.formatDate(end, "yyyy-MM-dd");
        startTimeField.text = Qt.formatTime(start, "HH:mm");
        endTimeField.text = Qt.formatTime(end, "HH:mm");
        locationField.text = "";
        allDayButton.checked = false;
        root.errorText = "";
    }

    function focusFirst() {
        titleField.forceActiveFocus();
        titleField.selectAll();
    }

    function submit() {
        const title = titleField.text.trim();
        const startDate = root.normalizedDate(startDateField.text);
        const endDate = root.normalizedDate(endDateField.text);
        if (title.length === 0) {
            root.errorText = Translation.tr("Add an event name");
            root.focusFirst();
            return false;
        }
        if (!startDate || !endDate || (!allDayButton.checked
                && (!root.normalizedTime(startTimeField.text) || !root.normalizedTime(endTimeField.text)))) {
            root.errorText = Translation.tr("Check the date and time fields");
            return false;
        }

        let start = allDayButton.checked
            ? Qt.formatDate(startDate, "yyyy-MM-dd")
            : root.localIso(startDate, startTimeField.text.trim());
        let end = allDayButton.checked
            ? Qt.formatDate(endDate, "yyyy-MM-dd")
            : root.localIso(endDate, endTimeField.text.trim());
        if (new Date(end) <= new Date(start)) {
            if (allDayButton.checked) {
                const nextDay = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + 1);
                end = Qt.formatDate(nextDay, "yyyy-MM-dd");
            } else {
                root.errorText = Translation.tr("End time must be after start time");
                return false;
            }
        }

        root.errorText = "";
        root.submitted({
            summary: title,
            start: start,
            end: end,
            allDay: allDayButton.checked,
            location: locationField.text.trim(),
            description: ""
        });
        return true;
    }

    Keys.onEscapePressed: event => {
        root.cancelled();
        event.accepted = true;
    }

    ColumnLayout {
        id: formColumn
        anchors.fill: parent
        spacing: Appearance.sizes.elevationMargin

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.sizes.elevationMargin

            RippleButton {
                implicitWidth: Appearance.sizes.elevationMargin * 4
                implicitHeight: implicitWidth
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                colRipple: Appearance.colors.colSurfaceContainerHighestActive
                onClicked: root.cancelled()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Translation.tr("New event")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }
                StyledText {
                    text: Translation.tr("Only the essentials — you can refine it later in Calendar")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        ToolbarTextField {
            id: titleField
            Layout.fillWidth: true
            Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
            placeholderText: Translation.tr("Event name")
            colBackground: Appearance.colors.colSurfaceContainerHigh
            enabled: !root.busy
            onAccepted: root.submit()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.sizes.elevationMargin / 2

            ToolbarTextField {
                id: startDateField
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
                placeholderText: Translation.tr("Start date · YYYY-MM-DD")
                colBackground: Appearance.colors.colSurfaceContainerHigh
                enabled: !root.busy
            }
            ToolbarTextField {
                id: startTimeField
                Layout.preferredWidth: parent.width / 4
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
                placeholderText: Translation.tr("Start · HH:MM")
                colBackground: Appearance.colors.colSurfaceContainerHigh
                visible: !allDayButton.checked
                enabled: !root.busy
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.sizes.elevationMargin / 2

            ToolbarTextField {
                id: endDateField
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
                placeholderText: Translation.tr("End date · YYYY-MM-DD")
                colBackground: Appearance.colors.colSurfaceContainerHigh
                enabled: !root.busy
            }
            ToolbarTextField {
                id: endTimeField
                Layout.preferredWidth: parent.width / 4
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
                placeholderText: Translation.tr("End · HH:MM")
                colBackground: Appearance.colors.colSurfaceContainerHigh
                visible: !allDayButton.checked
                enabled: !root.busy
            }
        }

        ToolbarTextField {
            id: locationField
            Layout.fillWidth: true
            Layout.preferredHeight: Appearance.sizes.elevationMargin * 3
            placeholderText: Translation.tr("Location · optional")
            colBackground: Appearance.colors.colSurfaceContainerHigh
            enabled: !root.busy
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.sizes.elevationMargin

            RippleButton {
                id: allDayButton
                property bool checked: false
                implicitWidth: allDayContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                implicitHeight: Appearance.sizes.elevationMargin * 3
                buttonRadius: Appearance.rounding.full
                colBackground: checked ? Appearance.colors.colSecondaryContainer : Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: checked ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
                colRipple: checked ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive
                onClicked: checked = !checked

                RowLayout {
                    id: allDayContent
                    anchors.centerIn: parent
                    spacing: Appearance.sizes.elevationMargin / 2
                    MaterialSymbol {
                        text: allDayButton.checked ? "check" : "schedule"
                        iconSize: Appearance.font.pixelSize.normal
                        color: allDayButton.checked ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                    }
                    StyledText {
                        text: Translation.tr("All day")
                        color: allDayButton.checked ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.errorText
                visible: text.length > 0
                elide: Text.ElideRight
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
            }

            RippleButton {
                implicitWidth: createContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                implicitHeight: Appearance.sizes.elevationMargin * 3
                buttonRadius: Appearance.rounding.full
                enabled: !root.busy
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: root.submit()

                RowLayout {
                    id: createContent
                    anchors.centerIn: parent
                    spacing: Appearance.sizes.elevationMargin / 2
                    MaterialLoadingIndicator {
                        implicitWidth: Appearance.font.pixelSize.normal
                        implicitHeight: implicitWidth
                        visible: root.busy
                    }
                    MaterialSymbol {
                        visible: !root.busy
                        text: "add"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        text: root.busy ? Translation.tr("Creating…") : Translation.tr("Create event")
                        color: Appearance.colors.colOnPrimaryContainer
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
