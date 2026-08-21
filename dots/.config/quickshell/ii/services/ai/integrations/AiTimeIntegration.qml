pragma ComponentBehavior: Bound

import QtQuick
import qs.services

/**
 * The small, typed boundary around the shell's local time services.
 *
 * This adapter intentionally does not own a clock, alarms file, calendar
 * backend or weather request. It turns the existing singleton data into
 * bounded DTOs, and turns an approved reminder into the exact AlarmService
 * call that persists it.
 */
QtObject {
    id: root

    readonly property int maximumLabelLength: 160
    readonly property int maximumCalendarEvents: 20

    function boundedText(value: var, maximum = root.maximumLabelLength): string {
        return String(value ?? "").trim().slice(0, maximum);
    }

    function dateKey(date: var): string {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function clockTime(date: var): string {
        return Qt.formatTime(date, "HH:mm");
    }

    function parseDateOnly(value: var): var {
        const text = String(value ?? "").trim();
        if (!/^\d{4}-\d{2}-\d{2}$/.test(text))
            return null;
        const parts = text.split("-").map(Number);
        const result = new Date(parts[0], parts[1] - 1, parts[2]);
        if (root.dateKey(result) !== text)
            return null;
        return result;
    }

    function relativeMinutes(value: var): var {
        const text = String(value ?? "").trim().toLocaleLowerCase();
        const match = text.match(/^(\d+)\s*(m|min|mins|minute|minutes|minuto|minutos|h|hr|hrs|hour|hours|hora|horas|d|day|days|dia|dias)$/);
        if (!match)
            return null;
        const amount = Number(match[1]);
        const unit = match[2];
        const multiplier = ["h", "hr", "hrs", "hour", "hours", "hora", "horas"].includes(unit) ? 60
            : (["d", "day", "days", "dia", "dias"].includes(unit) ? 1440 : 1);
        const minutes = amount * multiplier;
        return Number.isInteger(minutes) && minutes >= 1 && minutes <= 525600 ? minutes : null;
    }

    /**
     * Converts the wire format to an immutable local minute. The alarm
     * service has minute precision, so a past minute is rejected rather than
     * silently becoming an alarm on a later day.
     */
    function normalizeReminder(args: var): var {
        const hasRelative = args?.whenRelative !== undefined && args?.whenRelative !== null;
        const hasAbsolute = String(args?.whenAbsolute ?? "").trim().length > 0;
        if (hasRelative === hasAbsolute)
            return { ok: false, reason: "chooseOneTime" };

        const label = root.boundedText(args?.label);
        if (label.length === 0)
            return { ok: false, reason: "missingLabel" };

        let target = null;
        if (hasRelative) {
            const minutes = root.relativeMinutes(args.whenRelative);
            if (minutes === null)
                return { ok: false, reason: "invalidRelativeTime" };
            target = new Date(Date.now() + minutes * 60 * 1000);
        } else {
            const raw = String(args.whenAbsolute).trim();
            // Date-only strings are UTC in JavaScript and omit the time the
            // user asked for. Require an ISO local date-time instead.
            if (!raw.includes("T"))
                return { ok: false, reason: "invalidAbsoluteTime" };
            target = new Date(raw);
            if (isNaN(target.getTime()))
                return { ok: false, reason: "invalidAbsoluteTime" };
        }

        target.setSeconds(0, 0);
        if (target.getTime() <= Date.now())
            return { ok: false, reason: "timeInPast" };

        return {
            ok: true,
            reminder: {
                label: label,
                date: root.dateKey(target),
                time: root.clockTime(target),
                whenAbsolute: target.toISOString(),
                displayTime: Qt.formatDateTime(target, "ddd dd MMM · HH:mm"),
                // No selected weekday: AlarmService turns it off after this
                // one local calendar date rings.
                days: [false, false, false, false, false, false, false]
            }
        };
    }

    function createReminder(args: var): var {
        const normalized = root.normalizeReminder(args);
        if (!normalized.ok)
            return normalized;
        if (!Persistent.ready)
            return { ok: false, reason: "alarmsNotReady" };

        const reminder = normalized.reminder;
        const created = AlarmService.addAlarm(reminder.time, reminder.label, reminder.days, reminder.date);
        if (!created)
            return { ok: false, reason: "alarmCreateFailed" };
        return { ok: true, reminder: reminder };
    }

    function alarms(): var {
        const list = Array.from(AlarmService.alarms ?? []);
        const results = [];
        for (let i = 0; i < list.length && results.length < 20; i++) {
            const alarm = list[i] ?? ({});
            if (alarm.enabled !== true)
                continue;
            const days = Array.from(alarm.days ?? []);
            results.push({
                label: root.boundedText(alarm.label),
                time: String(alarm.time ?? ""),
                date: String(alarm.date ?? ""),
                repeats: days.some(day => day === true)
            });
        }
        return results;
    }

    function calendarEvents(args: var): var {
        if (!CalendarService.khalAvailable)
            return { available: false, events: [] };

        const now = new Date();
        let from = args?.from ? root.parseDateOnly(args.from) : new Date(now.getFullYear(), now.getMonth(), now.getDate());
        let to = args?.to ? root.parseDateOnly(args.to) : new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7);
        if (!from || !to || to.getTime() < from.getTime())
            return { available: true, error: "invalidDateRange", events: [] };
        to.setHours(23, 59, 59, 999);

        const rangeDays = Math.floor((to.getTime() - from.getTime()) / (24 * 60 * 60 * 1000));
        if (rangeDays > 31)
            return { available: true, error: "dateRangeTooLarge", events: [] };

        const limit = Math.max(1, Math.min(root.maximumCalendarEvents, Number(args?.limit ?? 10) || 10));
        const events = [];
        for (let offset = 0; offset <= rangeDays && events.length < limit; offset++) {
            const day = new Date(from);
            day.setDate(day.getDate() + offset);
            for (const event of Array.from(CalendarService.getTasksByDate(day) ?? [])) {
                const start = new Date(event?.startDate);
                const end = new Date(event?.endDate);
                if (isNaN(start.getTime()))
                    continue;
                events.push({
                    title: root.boundedText(event?.content),
                    start: Qt.formatDateTime(start, "yyyy-MM-dd HH:mm"),
                    end: isNaN(end.getTime()) ? "" : Qt.formatDateTime(end, "yyyy-MM-dd HH:mm"),
                    calendar: root.boundedText(event?.calendar, 80),
                    description: root.boundedText(event?.description, 240)
                });
                if (events.length >= limit)
                    break;
            }
        }
        return {
            available: true,
            events: events.sort((left, right) => String(left.start).localeCompare(String(right.start)))
        };
    }

    function weather(): var {
        // Weather owns caching and the actual request. Calling it here may
        // refresh stale data, so the tool's envelope always marks network use.
        Weather.getData();
        const current = Weather.data ?? ({});
        const forecast = Array.from(Weather.forecastData ?? []).slice(0, 3).map(day => ({
                    date: String(day?.date ?? ""),
                    minimum: Weather.useUSCS ? `${day?.minF ?? ""}°F` : `${day?.minC ?? ""}°C`,
                    maximum: Weather.useUSCS ? `${day?.maxF ?? ""}°F` : `${day?.maxC ?? ""}°C`,
                    condition: Weather.getWeatherDescription(day?.code)
                }));
        return {
            city: root.boundedText(current.city, 80),
            condition: root.boundedText(current.wDesc, 80),
            temperature: String(current.temp ?? ""),
            feelsLike: String(current.tempFeelsLike ?? ""),
            precipitation: String(current.precip ?? ""),
            humidity: String(current.humidity ?? ""),
            wind: String(current.wind ?? ""),
            forecast: forecast,
            refreshing: Weather.forecastLoading === true
        };
    }
}
