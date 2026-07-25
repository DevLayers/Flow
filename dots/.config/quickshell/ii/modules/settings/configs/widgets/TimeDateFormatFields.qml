import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 10

		TipBox {
        Layout.fillWidth: true
        isFirst: true
        text: Translation.tr(
        		"d/dd = day, M/MM = month, yy/yyyy = year, ddd/dddd = weekday, MMM/MMMM = month name, "
        		+ "h/hh = hour (12h), H/HH = hour (24h), m/mm = minute, s/ss = second, ap/AP = am/pm. "
        		+ "\nWrap fixed text in single quotes, e.g. \"ddd, dd/MM/yyyy 'at' hh:mm ap\"."
        )
    }

    ContentSubsectionLabel {
        text: Translation.tr("Time")
    }
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: "hh:mm"
        text: Config.options.time.format
        onEditingFinished: {
            const value = text.trim();
            if (value.length === 0 || value === Config.options.time.format)
                return;
            DateUtils.syncHyprlockTimeFormat(value);
            Config.options.time.format = value;
        }
    }
    StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer2
        text: Translation.tr("Preview: %1").arg(DateTime.time)
    }

    ContentSubsectionLabel {
        text: Translation.tr("Seconds")
    }
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: "ss"
        text: Config.options.time.secondsFormat
        onEditingFinished: {
            const value = text.trim();
            if (value.length === 0 || value === Config.options.time.secondsFormat)
                return;
            Config.options.time.secondsFormat = value;
        }
    }
    StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer2
        text: Translation.tr("Preview: %1").arg(DateTime.seconds)
    }

    ContentSubsectionLabel {
        text: Translation.tr("Date (bar & widgets)")
    }
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: "dd/MM, ddd"
        text: Config.options.time.dateFormat
        onEditingFinished: {
            const value = text.trim();
            if (value.length === 0 || value === Config.options.time.dateFormat)
                return;
            Config.options.time.dateFormat = value;
        }
    }
    StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer2
        text: Translation.tr("Preview: %1").arg(DateTime.longDate)
    }

    ContentSubsectionLabel {
        text: Translation.tr("Short date")
    }
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: "dd/MM"
        text: Config.options.time.shortDateFormat
        onEditingFinished: {
            const value = text.trim();
            if (value.length === 0 || value === Config.options.time.shortDateFormat)
                return;
            Config.options.time.shortDateFormat = value;
        }
    }
    StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer2
        text: Translation.tr("Preview: %1").arg(DateTime.shortDate)
    }

    ContentSubsectionLabel {
        text: Translation.tr("Date with year")
    }
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: "dd/MM/yyyy"
        text: Config.options.time.dateWithYearFormat
        onEditingFinished: {
            const value = text.trim();
            if (value.length === 0 || value === Config.options.time.dateWithYearFormat)
                return;
            Config.options.time.dateWithYearFormat = value;
        }
    }
    StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer2
        text: Translation.tr("Preview: %1").arg(DateTime.date)
    }
}
