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
    property bool showHeadless: AppStats.showHeadless

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

    /// The chart series for the current range, metric and selection.
    readonly property var chartValues: {
        AppStats.history;
        const key = root.selectedKey.length > 0 ? root.selectedKey : null;
        const length = root.isSingleDay ? 24 : root.dates.length;
        const out = new Array(length).fill(0);
        for (const field of root.metric.fields) {
            const series = root.isSingleDay ? AppStats.hourlySeries(root.dates, field, key) : AppStats.dailySeries(root.dates, field, key);
            for (let i = 0; i < length; i++)
                out[i] += series[i] ?? 0;
        }
        return out;
    }

    readonly property var chartLabels: {
        if (root.isSingleDay)
            return Array.from({
                "length": 24
            }, (unused, hour) => Format.hourLabel(hour));
        return root.dates.map(date => Format.dayLabel(date));
    }

    function refresh() {
        AppStats.ensureDates(root.dates);
        AppStats.refresh();
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

                Card {
                    Layout.fillWidth: true
                    implicitHeight: summaryLayout.implicitHeight + 32

                    RowLayout {
                        id: summaryLayout
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 24

                        StatChip {
                            icon: "schedule"
                            label: root.selectedKey.length > 0 ? Translation.tr("Screen time") : Translation.tr("Total screen time")
                            value: Format.duration(root.selectedRecord ? root.selectedRecord.fg : root.summary.totals.fg)
                        }

                        StatChip {
                            icon: "bolt"
                            label: Translation.tr("Energy")
                            value: {
                                const rec = root.selectedRecord ?? root.summary.totals;
                                return Format.energyFromMj(rec.mjFg + rec.mjBg);
                            }
                        }

                        StatChip {
                            icon: "rocket_launch"
                            label: Translation.tr("Launches")
                            value: Format.count(root.selectedRecord ? root.selectedRecord.launches : root.summary.totals.launches)
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Per-app watt-hours are modelled from CPU, GPU and memory
                        // shares, so the share that belongs to no app is the honest
                        // measure of how much weight they carry. Kept on screen.
                        StatChip {
                            visible: root.summary.system.mjFg + root.summary.system.mjBg > 0
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
                                text: root.selectedKey.length > 0 ? `${root.metric.name} · ${AppStats.displayName(root.selectedKey)}` : `${root.metric.name} · ${Translation.tr("all apps")}`
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
                            labelStride: root.isSingleDay ? 3 : Math.max(1, Math.ceil(root.dates.length / 10))
                            highlightIndex: root.isSingleDay ? DateTime.clock.date.getHours() : root.dates.length - 1
                            formatValue: value => root.formatMetric(value)
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: detailLayout.implicitHeight + 32
                    visible: root.selectedRecord !== null

                    RowLayout {
                        id: detailLayout
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 24

                        StatChip {
                            label: Translation.tr("Background")
                            value: Format.duration(root.selectedRecord?.bg ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("Focused")
                            value: Format.duration(root.selectedRecord?.focus ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("CPU time")
                            value: Format.duration(root.selectedRecord?.cpu ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("GPU time")
                            value: Format.duration(root.selectedRecord?.gpu ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("Memory avg")
                            value: Format.memory(root.selectedRecord?.ramAvg ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("Memory peak")
                            value: Format.memory(root.selectedRecord?.ramPeak ?? 0)
                        }

                        StatChip {
                            label: Translation.tr("Sessions")
                            value: Format.count(root.selectedRecord?.sessions ?? 0)
                        }

                        Item {
                            Layout.fillWidth: true
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
                            toggled: root.showHeadless
                            onClicked: root.showHeadless = !root.showHeadless

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "terminal"
                                iconSize: 18
                                color: root.showHeadless ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            }

                            StyledToolTip {
                                text: Translation.tr("Show background services")
                            }
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
