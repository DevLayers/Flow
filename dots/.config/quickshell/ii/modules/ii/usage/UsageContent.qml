import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "UsageFormat.js" as Format

/**
 * The body of the usage overlay: a histogram and summary on the left, the ranked
 * app list on the right.
 *
 * Picking an app narrows the chart and the summary to it rather than opening a
 * separate view — the question being asked is almost always "how does this one
 * compare to the rest of the day", and swapping the whole panel loses that.
 */
Item {
    id: root

    readonly property var ranges: [
        {
            "days": 1,
            "name": Translation.tr("Today")
        },
        {
            "days": 7,
            "name": Translation.tr("7 days")
        },
        {
            "days": 30,
            "name": Translation.tr("30 days")
        }
    ]

    /// `fields` are summed straight out of a stored hour tuple, so a metric that
    /// spans several of them (energy is foreground plus background) needs no
    /// special case in the chart or the list.
    readonly property var metrics: [
        {
            "key": "fg",
            "icon": "schedule",
            "name": Translation.tr("Screen time"),
            "fields": ["fg"],
            "kind": "duration"
        },
        {
            "key": "focus",
            "icon": "point_scan",
            "name": Translation.tr("Focused"),
            "fields": ["focus"],
            "kind": "duration"
        },
        {
            "key": "energy",
            "icon": "bolt",
            "name": Translation.tr("Energy"),
            "fields": ["mjFg", "mjBg"],
            "kind": "energy"
        },
        {
            "key": "cpu",
            "icon": "memory",
            "name": Translation.tr("CPU"),
            "fields": ["cpu"],
            "kind": "duration"
        },
        {
            "key": "gpu",
            "icon": "stadia_controller",
            "name": Translation.tr("GPU"),
            "fields": ["gpu"],
            "kind": "duration"
        }
    ]

    property int rangeIndex: 0
    property int metricIndex: 0
    property string selectedKey: ""
    /// Kept in the config rather than here so the chart, which asks the service
    /// directly, cannot end up filtering differently from the list.
    readonly property bool showHeadless: AppStats.showHeadless

    readonly property var metric: root.metrics[root.metricIndex]
    readonly property bool isSingleDay: root.ranges[root.rangeIndex].days === 1
    readonly property var dates: AppStats.recentDates(root.ranges[root.rangeIndex].days)

    readonly property var summary: {
        // Touching `history` here is what makes every derived figure recompute when
        // a day file lands; `dates` alone does not change when the data does.
        AppStats.history;
        return AppStats.summarize(root.dates, {
            "headless": root.showHeadless
        });
    }

    /// Apps carrying a nonzero value for the selected metric, largest first. The
    /// unattributed remainder joins the list only for energy, the one metric it
    /// actually holds.
    readonly property var ranked: {
        const list = root.summary.apps.filter(rec => root.metricValue(rec) > 0);
        if (root.metric.key === "energy" && root.metricValue(root.summary.system) > 0)
            list.push(root.summary.system);
        list.sort((a, b) => root.metricValue(b) - root.metricValue(a));
        return list;
    }
    readonly property real rankedMax: root.ranked.length > 0 ? root.metricValue(root.ranked[0]) : 0

    /// The selected metric over everything in scope. Screen time is the device's
    /// own figure rather than the sum of the list, for the same reason the chart
    /// draws it that way: two windows on screen are one hour of screen time.
    readonly property real metricTotal: {
        if (root.selectedRecord)
            return root.metricValue(root.selectedRecord);
        if (root.metric.key === "fg")
            return root.deviceScreenTime;
        return root.ranked.reduce((total, rec) => total + root.metricValue(rec), 0);
    }

    readonly property var selectedRecord: {
        for (const rec of root.ranked) {
            if (rec.key === root.selectedKey)
                return rec;
        }
        return null;
    }

    function metricValue(rec) {
        if (!rec)
            return 0;
        let sum = 0;
        for (const field of root.metric.fields)
            sum += rec[field] ?? 0;
        return sum;
    }

    function formatMetric(value) {
        return root.metric.kind === "energy" ? Format.energyFromMj(value) : Format.duration(value);
    }

    /// Compact enough for the vertical axis, where each tick has a gutter a few
    /// characters wide.
    function formatTick(value) {
        return root.metric.kind === "energy" ? Format.energyFromMj(value) : Format.durationShort(value);
    }

    /// Whose series the chart draws. With no app picked, screen time is asked of
    /// the device row instead of summed over the apps: two windows on screen at
    /// once are two apps' worth of foreground time but still only one hour of it.
    readonly property string chartKey: {
        if (root.selectedKey.length > 0)
            return root.selectedKey;
        return root.metric.key === "fg" ? AppStats.systemKey : "";
    }

    function seriesFor(key) {
        const length = root.isSingleDay ? 24 : root.dates.length;
        const out = new Array(length).fill(0);
        for (const field of root.metric.fields) {
            const series = root.isSingleDay ? AppStats.hourlySeries(root.dates, field, key) : AppStats.dailySeries(root.dates, field, key);
            for (let i = 0; i < length; i++)
                out[i] += series[i] ?? 0;
        }
        return out;
    }

    /// One value per bucket for the device as a whole. Built from hours rather than
    /// from a day total, because that is the resolution its fallback works at.
    function deviceSeries(field) {
        const perDay = root.dates.map(date => AppStats.deviceHours(date, field));
        if (root.isSingleDay)
            return perDay[0] ?? new Array(24).fill(0);
        return perDay.map(hours => hours.reduce((sum, value) => sum + value, 0));
    }

    /// The chart series for the current range, metric and selection.
    readonly property var chartValues: {
        AppStats.history;
        if (root.chartKey === AppStats.systemKey)
            return root.deviceSeries("fg");
        if (root.selectedKey.length > 0)
            return root.seriesFor(root.selectedKey);

        const values = root.seriesFor(null);
        if (root.metric.key !== "energy")
            return values;

        // The share that belongs to no app is still energy the machine spent, and
        // the list beside the chart already carries it as a row. Leaving it out of
        // the chart alone would put three totals for one metric on one screen.
        const system = root.seriesFor(AppStats.systemKey);
        return values.map((value, index) => value + (system[index] ?? 0));
    }

    /// Screen time for the whole range, counted once rather than once per window.
    readonly property real deviceScreenTime: {
        AppStats.history;
        return root.dates.reduce((total, date) => total + AppStats.deviceHours(date, "fg").reduce((sum, value) => sum + value, 0), 0);
    }

    /// Every `dayStride`-th label is drawn, counted back from today.
    readonly property int dayStride: Math.max(1, Math.ceil(root.dates.length / 10))

    readonly property var chartLabels: {
        if (root.isSingleDay)
            return Array.from({
                "length": 24
            }, (unused, hour) => Format.hourLabel(hour));

        // Spelled out at both drawn ends of the axis and wherever a month turns
        // over, so the range says where in the year it sits. The left end is the
        // first label the stride actually reaches, not date zero, which a 30-day
        // range skips.
        const first = (root.dates.length - 1) % root.dayStride;
        return root.dates.map((date, index) => Format.dayLabel(date, index === first || index === root.dates.length - 1 || date.slice(-2) === "01"));
    }

    function refresh() {
        AppStats.ensureDates(root.dates);
        AppStats.refresh();
    }

    /// Moves the selection `delta` rows through the list, selecting the first row
    /// from nothing and falling off the top back to nothing.
    function moveSelection(delta) {
        if (root.ranked.length === 0)
            return;

        let index = -1;
        for (let i = 0; i < root.ranked.length; i++) {
            if (root.ranked[i].key === root.selectedKey) {
                index = i;
                break;
            }
        }
        const next = index + delta;
        if (next < 0) {
            root.selectedKey = "";
            return;
        }
        const clamped = Math.min(next, root.ranked.length - 1);
        root.selectedKey = root.ranked[clamped].key;
        appList.positionViewAtIndex(clamped, ListView.Contain);
    }

    /// Handles a key press forwarded by the window. Returns whether it was ours.
    ///
    /// Tab cycles the metric rather than one digit per tab: on an AZERTY keyboard
    /// the number row needs Shift, so digits alone would leave half the panel
    /// unreachable. They still work where they are unshifted.
    function handleKey(key) {
        if (key >= Qt.Key_1 && key < Qt.Key_1 + root.metrics.length) {
            root.metricIndex = key - Qt.Key_1;
            return true;
        }
        switch (key) {
        case Qt.Key_Tab:
            root.metricIndex = (root.metricIndex + 1) % root.metrics.length;
            return true;
        case Qt.Key_Backtab:
            root.metricIndex = (root.metricIndex + root.metrics.length - 1) % root.metrics.length;
            return true;
        case Qt.Key_Left:
            root.rangeIndex = Math.max(0, root.rangeIndex - 1);
            return true;
        case Qt.Key_Right:
            root.rangeIndex = Math.min(root.ranges.length - 1, root.rangeIndex + 1);
            return true;
        case Qt.Key_Up:
            root.moveSelection(-1);
            return true;
        case Qt.Key_Down:
            root.moveSelection(1);
            return true;
        }
        return false;
    }

    onDatesChanged: AppStats.ensureDates(root.dates)
    Component.onCompleted: root.refresh()

    // A selection is only meaningful while the app is still in the list; changing
    // metric or range can drop it out entirely.
    onRankedChanged: {
        if (root.selectedKey.length > 0 && !root.selectedRecord)
            root.selectedKey = "";
    }

    component Card: Rectangle {
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.normal
    }

    component StatChip: ColumnLayout {
        id: chip

        required property string label
        required property string value
        property string icon: ""
        property bool shown: true
        /// The metric this chip would repeat. The card leads with whichever metric
        /// is selected, so the chip that would say the same figure twice steps aside.
        property string metricKey: ""

        visible: chip.shown && chip.metricKey !== root.metric.key
        spacing: 2

        RowLayout {
            spacing: 4

            MaterialSymbol {
                visible: chip.icon.length > 0
                text: chip.icon
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        StyledText {
            text: chip.value
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ButtonGroup {
                spacing: 4
                padding: 0

                Repeater {
                    model: root.ranges

                    delegate: SelectionGroupButton {
                        required property var modelData
                        required property int index

                        buttonText: modelData.name
                        toggled: root.rangeIndex === index
                        leftmost: index === 0
                        rightmost: index === root.ranges.length - 1
                        onClicked: root.rangeIndex = index
                    }
                }
            }

            // Up here with the range and the metric because it is one of them: it
            // decides what the whole panel counts, not just which rows the list
            // shows. Left in the list header it silently moved the totals.
            RippleButton {
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                horizontalPadding: 12
                toggled: root.showHeadless
                onClicked: Config.options.appStats.showHeadless = !root.showHeadless

                contentItem: RowLayout {
                    spacing: 6

                    MaterialSymbol {
                        text: "terminal"
                        iconSize: 16
                        color: root.showHeadless ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                    }

                    StyledText {
                        text: Translation.tr("Services")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.showHeadless ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                    }
                }

                StyledToolTip {
                    text: Translation.tr("Count background services in the list and the totals")
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ButtonGroup {
                spacing: 4
                padding: 0

                Repeater {
                    model: root.metrics

                    delegate: SelectionGroupButton {
                        required property var modelData
                        required property int index

                        buttonIcon: modelData.icon
                        buttonText: modelData.name
                        toggled: root.metricIndex === index
                        leftmost: index === 0
                        rightmost: index === root.metrics.length - 1
                        onClicked: root.metricIndex = index
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // One card for whatever is being looked at, rather than a second one
                // that appears underneath when an app is picked: the figures for the
                // selection belong where the figures for everything were.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: summaryFlow.implicitHeight + 32

                    Flow {
                        id: summaryFlow
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 16
                        }
                        spacing: 22

                        // The card leads with the metric the tabs are set to, so the
                        // figure the question was asked about is the first one
                        // answered. Whichever chip below repeats it drops out.
                        StatChip {
                            icon: root.metric.icon
                            label: root.selectedRecord === null && root.metric.key === "fg" ? Translation.tr("Device screen time") : root.metric.name
                            value: root.formatMetric(root.metricTotal)
                        }

                        StatChip {
                            metricKey: "fg"
                            icon: "schedule"
                            label: root.selectedKey.length > 0 ? Translation.tr("Screen time") : Translation.tr("Device screen time")
                            value: Format.duration(root.selectedRecord ? root.selectedRecord.fg : root.deviceScreenTime)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            icon: "visibility_off"
                            label: Translation.tr("Background")
                            value: Format.duration(root.selectedRecord?.bg ?? 0)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            metricKey: "focus"
                            icon: "point_scan"
                            label: Translation.tr("Focused")
                            value: Format.duration(root.selectedRecord?.focus ?? 0)
                        }

                        // Apps plus the share that belongs to none of them, matching
                        // the chart and the list rather than counting the apps alone.
                        StatChip {
                            metricKey: "energy"
                            icon: "bolt"
                            label: Translation.tr("Energy")
                            value: {
                                if (root.selectedRecord)
                                    return Format.energyFromMj(root.selectedRecord.mjFg + root.selectedRecord.mjBg);

                                const apps = root.summary.totals;
                                const system = root.summary.system;
                                return Format.energyFromMj(apps.mjFg + apps.mjBg + system.mjFg + system.mjBg);
                            }
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            metricKey: "cpu"
                            icon: "memory"
                            label: Translation.tr("CPU time")
                            value: Format.duration(root.selectedRecord?.cpu ?? 0)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            metricKey: "gpu"
                            icon: "stadia_controller"
                            label: Translation.tr("GPU time")
                            value: Format.duration(root.selectedRecord?.gpu ?? 0)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            icon: "memory_alt"
                            label: Translation.tr("Memory avg")
                            value: Format.memory(root.selectedRecord?.ramAvg ?? 0)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            icon: "vertical_align_top"
                            label: Translation.tr("Memory peak")
                            value: Format.memory(root.selectedRecord?.ramPeak ?? 0)
                        }

                        StatChip {
                            icon: "rocket_launch"
                            label: Translation.tr("Launches")
                            value: Format.count(root.selectedRecord ? root.selectedRecord.launches : root.summary.totals.launches)
                        }

                        StatChip {
                            shown: root.selectedRecord !== null
                            icon: "repeat"
                            label: Translation.tr("Sessions")
                            value: Format.count(root.selectedRecord?.sessions ?? 0)
                        }

                        // Per-app watt-hours are modelled from CPU, GPU and memory
                        // shares, so the share that belongs to no app is the honest
                        // measure of how much weight they carry. Kept on screen.
                        StatChip {
                            shown: root.selectedRecord === null && root.summary.system.mjFg + root.summary.system.mjBg > 0
                            icon: "help"
                            label: Translation.tr("Unattributed")
                            value: {
                                const system = root.summary.system.mjFg + root.summary.system.mjBg;
                                const apps = root.summary.totals.mjFg + root.summary.totals.mjBg;
                                const total = system + apps;
                                return total > 0 ? `${Math.round(system / total * 100)} %` : "—";
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: {
                                    if (root.selectedKey.length > 0)
                                        return `${root.metric.name} · ${AppStats.displayName(root.selectedKey)}`;
                                    const isDevice = root.chartKey === AppStats.systemKey || root.metric.key === "energy";
                                    const scope = isDevice ? Translation.tr("device") : Translation.tr("all apps");
                                    return `${root.metric.name} · ${scope}`;
                                }
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                            }

                            RippleButton {
                                visible: root.selectedKey.length > 0
                                implicitHeight: 30
                                buttonRadius: Appearance.rounding.full
                                horizontalPadding: 12
                                onClicked: root.selectedKey = ""

                                contentItem: StyledText {
                                    text: Translation.tr("Clear selection")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }

                        UsageBarChart {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            values: root.chartValues
                            labels: root.chartLabels
                            tooltipLabels: root.isSingleDay ? root.chartLabels : root.dates
                            labelStride: root.isSingleDay ? 3 : root.dayStride
                            labelAnchorEnd: !root.isSingleDay
                            highlightIndex: root.isSingleDay ? DateTime.clock.date.getHours() : root.dates.length - 1
                            timeScale: root.metric.kind === "duration"
                            // Millijoules per watt-hour, the figure the axis is
                            // labelled in.
                            valueUnit: root.metric.kind === "energy" ? 3600000 : 1
                            formatValue: value => root.formatMetric(value)
                            formatTick: value => root.formatTick(value)
                        }
                    }
                }

            }

            Card {
                Layout.fillHeight: true
                implicitWidth: 400

                ColumnLayout {
                    anchors {
                        fill: parent
                        topMargin: 16
                        bottomMargin: 8
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 4
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: root.ranked.length > 0 ? Translation.tr("%1 apps").arg(root.ranked.length) : Translation.tr("No activity")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.full
                            onClicked: root.refresh()

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                            }

                            StyledToolTip {
                                text: Translation.tr("Refresh")
                            }
                        }
                    }

                    StyledListView {
                        id: appList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.ranked

                        delegate: UsageAppRow {
                            required property var modelData

                            width: appList.width
                            record: modelData
                            value: root.metricValue(modelData)
                            maxValue: root.rankedMax
                            valueText: root.formatMetric(root.metricValue(modelData))
                            selected: root.selectedKey === modelData.key
                            onClicked: root.selectedKey = (root.selectedKey === modelData.key ? "" : modelData.key)
                        }
                    }
                }

                // Only meaningful once the sampler is up; before that an empty list
                // means "not collecting yet", which is a different thing entirely.
                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: root.ranked.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: AppStats.running ? Translation.tr("Nothing recorded for this period yet.") : Translation.tr("The usage sampler is not running.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
