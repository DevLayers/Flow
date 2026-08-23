.pragma library

function snapToGrid(minutes, snapInterval) {
    return Math.round(minutes / snapInterval) * snapInterval;
}

function yToMinutes(y, startHour, startMinute, pixelsPerMinute) {
    return startHour * 60 + startMinute + (y / pixelsPerMinute);
}

function minutesToY(totalMinutes, startHour, startMinute, pixelsPerMinute) {
    return (totalMinutes - (startHour * 60 + startMinute)) * pixelsPerMinute;
}

function minutesToTimeStr(totalMinutes, format) {
    let clamped = Math.max(0, Math.min(totalMinutes, 24 * 60));
    let hour = Math.floor(clamped / 60);
    let minute = Math.round(clamped % 60);
    let d = new Date();
    d.setHours(hour, minute, 0, 0);
    return Qt.formatTime(d, format || "hh:mm");
}

function minutesToKhalTimeStr(totalMinutes) {
    let clamped = Math.max(0, Math.min(totalMinutes, 24 * 60));
    let hour = Math.floor(clamped / 60);
    let minute = Math.round(clamped % 60);
    return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute;
}

function getDateForDayIndex(dayIndex, firstDayOfWeek, todayFirst) {
    let d = new Date();
    if (todayFirst) {
        d.setDate(d.getDate() + dayIndex);
    } else {
        let currentConfigDayIndex = (d.getDay() - firstDayOfWeek + 6) % 7;
        d.setDate(d.getDate() - currentConfigDayIndex + dayIndex);
    }
    return d;
}

function parseTimeToMinutes(timeStr) {
    if (!timeStr) return null;
    let parts = timeStr.split(":");
    if (parts.length < 2) return null;
    let hour = parseInt(parts[0]);
    let minute = parseInt(parts[1]);
    if (isNaN(hour) || isNaN(minute)) return null;
    return hour * 60 + minute;
}

function withOpacity(colorValue, alpha) {
    if (!colorValue) return Qt.rgba(0, 0, 0, alpha);
    let color = Qt.color(colorValue);
    return Qt.rgba(color.r, color.g, color.b, alpha);
}

function isAllDayEvent(event) {
    if (!event) return false;
    let start = event.start || "";
    let end = event.end || "";
    // Common patterns for all-day events
    return (start === "00:00" && end === "23:59") ||
        (start === "00:00" && end === "00:00") ||
        (start === "00:00" && end === "24:00") ||
        (!event.start && !event.end);
}

function getAllDayEvents(events) {
    if (!events || !events.length) return [];
    return events.filter(evt => isAllDayEvent(evt));
}

function getTimedEvents(events) {
    if (!events || !events.length) return [];
    return events.filter(evt => !isAllDayEvent(evt));
}

function lerpColor(color1, color2, factor) {
    let c1 = Qt.color(color1);
    let c2 = Qt.color(color2);
    let f = Math.max(0, Math.min(1, factor));
    let r = c1.r + (c2.r - c1.r) * f;
    let g = c1.g + (c2.g - c1.g) * f;
    let b = c1.b + (c2.b - c1.b) * f;
    let a = c1.a + (c2.a - c1.a) * f;
    return Qt.rgba(r, g, b, a);
}

function getEventColorRadial(dayIndex, startMinutes, nextEvtData, maxDist, colors) {
    if (!nextEvtData) return colors.colSurfaceContainerHigh;

    let nextDay = nextEvtData.dayIndex;
    let nextStart = nextEvtData.startMinutes;

    let dx = dayIndex - nextDay;
    let dy = (startMinutes - nextStart) / 60.0;

    if (dx === 0 && dy === 0) return colors.colPrimary;

    let distance = Math.sqrt(dx * dx + dy * dy);
    let normalizedDist = Math.min(1.0, distance / maxDist);

    let c1, c2, ratio;
    if (normalizedDist < 0.33) {
        c1 = colors.colPrimary;
        c2 = colors.colSecondary;
        ratio = normalizedDist / 0.33;
    } else if (normalizedDist < 0.66) {
        c1 = colors.colSecondary;
        c2 = colors.colTertiary;
        ratio = (normalizedDist - 0.33) / 0.33;
    } else {
        c1 = colors.colTertiary;
        c2 = colors.colSurfaceContainerHighest;
        ratio = (normalizedDist - 0.66) / 0.34;
    }

    return lerpColor(c1, c2, ratio);
}

function computeEventLayout(events, parseFn) {
    if (!events || events.length === 0) return [];

    // Use internal parse function if not provided
    let parse = parseFn || parseTimeToMinutes;

    // 1. Prepare and sort timed events
    let timedEvents = events.filter(e => !isAllDayEvent(e)).map(e => {
        let start = parse(e.start);
        let end = parse(e.end);
        if (start === null || end === null) return null;

        // Handle midnight wrap
        if (end === 0 && start > 0) end = 24 * 60;

        return {
            event: e,
            start: start,
            end: end,
            colIndex: 0,
            totalCols: 1
        };
    }).filter(e => e !== null)
        .sort((a, b) => a.start - b.start || (b.end - b.start) - (a.end - a.start));

    if (timedEvents.length === 0) return [];

    // 2. Group overlapping events
    let groups = [];
    let currentGroup = [];
    let groupEnd = -1;

    for (let ev of timedEvents) {
        if (ev.start >= groupEnd) {
            if (currentGroup.length > 0) groups.push(currentGroup);
            currentGroup = [ev];
            groupEnd = ev.end;
        } else {
            currentGroup.push(ev);
            groupEnd = Math.max(groupEnd, ev.end);
        }
    }
    if (currentGroup.length > 0) groups.push(currentGroup);

    // 3. Assign columns within each group
    for (let group of groups) {
        let columns = []; // array of end times for each column

        for (let ev of group) {
            let placed = false;
            for (let i = 0; i < columns.length; i++) {
                if (ev.start >= columns[i]) {
                    ev.colIndex = i;
                    columns[i] = ev.end;
                    placed = true;
                    break;
                }
            }
            if (!placed) {
                ev.colIndex = columns.length;
                columns.push(ev.end);
            }
        }

        // 4. Set totalCols for everyone in this group
        for (let ev of group) {
            ev.totalCols = columns.length;
        }
    }

    return timedEvents;
}

// ─── Month view ───────────────────────────────────────────────
// `firstDayOfWeek` follows Config.options.time.firstDayOfWeek:
// 0 = Monday … 6 = Sunday. The JS weekday index of the first column is
// therefore (firstDayOfWeek + 1) % 7.

function pad2(value) {
    return (value < 10 ? "0" : "") + value;
}

function dayKeyOf(date) {
    if (!date)
        return "";
    return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

function sameDate(a, b) {
    if (!a || !b)
        return false;
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date, count) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + count);
}

// Clamps the day so "31 Jan + 1 month" lands in February instead of March.
function addMonths(date, count) {
    const firstOfTarget = new Date(date.getFullYear(), date.getMonth() + count, 1);
    const available = daysInMonth(firstOfTarget.getFullYear(), firstOfTarget.getMonth());
    return new Date(firstOfTarget.getFullYear(), firstOfTarget.getMonth(), Math.min(date.getDate(), available));
}

function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate();
}

function columnForJsDay(jsDay, firstDayOfWeek) {
    return (jsDay - firstDayOfWeek + 6) % 7;
}

function monthRowCount(year, month, firstDayOfWeek) {
    const lead = columnForJsDay(new Date(year, month, 1).getDay(), firstDayOfWeek);
    return Math.ceil((lead + daysInMonth(year, month)) / 7);
}

// One descriptor per grid cell, including the leading/trailing days that belong
// to the neighbouring months. Only whole weeks are produced.
function buildMonthCells(year, month, firstDayOfWeek, todayDate) {
    const lead = columnForJsDay(new Date(year, month, 1).getDay(), firstDayOfWeek);
    const cellCount = Math.ceil((lead + daysInMonth(year, month)) / 7) * 7;
    const cells = [];
    for (let i = 0; i < cellCount; i++) {
        const date = new Date(year, month, 1 - lead + i);
        cells.push({
            date: date,
            key: dayKeyOf(date),
            day: date.getDate(),
            inMonth: date.getMonth() === month && date.getFullYear() === year,
            isWeekend: date.getDay() === 0 || date.getDay() === 6,
            isToday: sameDate(date, todayDate),
            row: Math.floor(i / 7),
            column: i % 7
        });
    }
    return cells;
}

// `format` is Locale.ShortFormat and friends, passed in because this is a
// pragma library: the Locale enum only exists on the QML side.
function weekdayLabels(firstDayOfWeek, localeName, format) {
    const locale = localeName ? Qt.locale(localeName) : Qt.locale();
    const labels = [];
    for (let i = 0; i < 7; i++) {
        labels.push(locale.dayName((firstDayOfWeek + 1 + i) % 7, format));
    }
    return labels;
}

function isWeekendColumn(column, firstDayOfWeek) {
    const jsDay = (firstDayOfWeek + 1 + column) % 7;
    return jsDay === 0 || jsDay === 6;
}

// ─── Month view: event formatting ─────────────────────────────
// Month cells read CalendarService.events directly, so these work on Date
// objects rather than the "HH:mm" strings the week view uses.

function eventStartText(event, format) {
    if (!event || !event.startDate)
        return "";
    return Qt.formatTime(event.startDate, format || "hh:mm");
}

function eventRangeText(event, format) {
    if (!event || !event.startDate || !event.endDate)
        return "";
    return Qt.formatTime(event.startDate, format || "hh:mm") + " – " + Qt.formatTime(event.endDate, format || "hh:mm");
}

function khalTimeOf(date) {
    if (!date)
        return "00:00";
    return pad2(date.getHours()) + ":" + pad2(date.getMinutes());
}

// Resolve persisted color identifiers into the current Material You palette.
// The ICS value stores a semantic token, never a wallpaper-dependent hex.
function themeColorForToken(token, palette) {
    switch (String(token || "").trim().toLowerCase()) {
    case "primary": return palette.colPrimary;
    case "secondary": return palette.colSecondary;
    case "tertiary": return palette.colTertiary;
    case "error": return palette.colError;
    case "primarycontainer": return palette.colPrimaryContainer;
    case "secondarycontainer": return palette.colSecondaryContainer;
    case "tertiarycontainer": return palette.colTertiaryContainer;
    case "errorcontainer": return palette.colErrorContainer;
    default: return null;
    }
}

// Keep interaction feedback in the same Material semantic family as the
// persisted event token. Mixing a saturated token with on-surface turns it
// nearly black in dark schemes instead of yielding its intended hover color.
function themeHoverColorForToken(token, palette) {
    switch (String(token || "").trim().toLowerCase()) {
    case "primary": return palette.colPrimaryHover;
    case "secondary": return palette.colSecondaryHover;
    case "tertiary": return palette.colTertiaryHover;
    case "error": return palette.colErrorHover;
    case "primarycontainer": return palette.colPrimaryContainerHover;
    case "secondarycontainer": return palette.colSecondaryContainerHover;
    case "tertiarycontainer": return palette.colTertiaryContainerHover;
    case "errorcontainer": return palette.colErrorContainerHover;
    default: return palette.colSurfaceContainerHighestHover;
    }
}

// khal accepts ANSI names for calendar config. They are only an interchange
// representation; rendering still happens through Material tokens.
function themeTokenForCalendarColor(color) {
    switch (String(color || "").trim().toLowerCase()) {
    case "dark blue":
    case "light blue": return "primary";
    case "dark green":
    case "light green":
    case "light cyan": return "secondary";
    case "dark magenta":
    case "light magenta":
    case "yellow": return "tertiary";
    case "dark red":
    case "light red": return "error";
    default: return "";
    }
}

// Distinct hue per event so a month full of chips stays readable. An explicit
// event token wins, followed by the calendar token, then the existing themed
// rotation for calendars that do not opt into a colour.
function chipColor(event, palette) {
    if (!event)
        return palette.colSecondaryContainer;
    const explicit = themeColorForToken(event.colorToken, palette);
    if (explicit)
        return explicit;
    const calendar = themeColorForToken(themeTokenForCalendarColor(event.calendarColor), palette);
    if (calendar)
        return calendar;
    if (event.color)
        return event.color;
    return palette.colSecondaryContainer;
}

// ─── Moon phases ──────────────────────────────────────────────
// Local, offline computation. Sun/moon ecliptic longitudes follow Paul
// Schlyter's compact method plus the main lunar perturbation terms, which
// keeps phase timing within minutes — far beyond what a day-sized calendar
// badge needs. Pure Math/Date on purpose: no Qt.* here, so the functions
// stay testable outside the QML engine.

const MOON_SYNODIC_MONTH = 29.530588853;
const MOON_DEG = Math.PI / 180;

// One Nerd Font glyph per canonical phase, in phase order. JetBrainsMono
// Nerd Font ships the nf-md moon set on the supplementary plane
// (U+F0F61…U+F0F68): these exceed \uXXXX's four hex digits, so they are
// built from code points instead of escape literals.
const MOON_GLYPHS = [
    0xF0F64, // nf-md-moon_new
    0xF0F67, // nf-md-moon_waxing_crescent
    0xF0F61, // nf-md-moon_first_quarter
    0xF0F68, // nf-md-moon_waxing_gibbous
    0xF0F62, // nf-md-moon_full
    0xF0F66, // nf-md-moon_waning_gibbous
    0xF0F63, // nf-md-moon_last_quarter
    0xF0F65  // nf-md-moon_waning_crescent
].map(codePoint => String.fromCodePoint(codePoint));

function _normalizeDegrees(deg) {
    return ((deg % 360) + 360) % 360;
}

function _sinDeg(deg) {
    return Math.sin(deg * MOON_DEG);
}

function _cosDeg(deg) {
    return Math.cos(deg * MOON_DEG);
}

// Returns { index, illumination, elongationDeg, ageDays } or null.
// `index`: 0 new … 4 full … 7 waning crescent. `illumination`: 0…1.
function moonPhaseInfo(date) {
    if (!date || isNaN(date.getTime()))
        return null;
    // Noon local: the badge represents the middle of that day.
    const at = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
    const d = at.getTime() / 86400000 + 2440587.5 - 2451543.5; // days since 2000 Jan 0.0

    // Sun: true ecliptic longitude.
    const sunMeanAnomaly = 356.0470 + 0.9856002585 * d;
    const sunPerihelion = 282.9404 + 4.70935e-5 * d;
    const sunEcc = 0.016709 - 1.151e-9 * d;
    const sunEccAnomaly = sunMeanAnomaly + (180 / Math.PI) * sunEcc
        * _sinDeg(sunMeanAnomaly) * (1 + sunEcc * _cosDeg(sunMeanAnomaly));
    const sunTrueAnomaly = Math.atan2(
        Math.sqrt(1 - sunEcc * sunEcc) * _sinDeg(sunEccAnomaly),
        _cosDeg(sunEccAnomaly) - sunEcc
    ) / MOON_DEG;
    const sunLongitude = _normalizeDegrees(sunTrueAnomaly + sunPerihelion);

    // Moon: geocentric ecliptic longitude from orbital elements.
    const moonNode = 125.1228 - 0.0529538083 * d;
    const moonInclination = 5.1454;
    const moonPerigee = 318.0634 + 0.1643573223 * d;
    const moonEcc = 0.054900;
    const moonMeanAnomaly = 115.3654 + 13.0649929509 * d;
    // First-order seed, then Newton on the true Kepler equation
    // (E - deg*e*sin(E) - M = 0). Re-seeding with the first-order formula
    // again would diverge for the moon's eccentricity.
    let moonEccAnomaly = moonMeanAnomaly + (180 / Math.PI) * moonEcc
        * _sinDeg(moonMeanAnomaly);
    for (let keplerStep = 0; keplerStep < 2; keplerStep++) {
        const f = moonEccAnomaly - (180 / Math.PI) * moonEcc * _sinDeg(moonEccAnomaly) - moonMeanAnomaly;
        const df = 1 - (180 / Math.PI) * moonEcc * _cosDeg(moonEccAnomaly);
        moonEccAnomaly -= f / df;
    }
    const moonArgument = Math.atan2(
        Math.sqrt(1 - moonEcc * moonEcc) * _sinDeg(moonEccAnomaly),
        _cosDeg(moonEccAnomaly) - moonEcc
    ) / MOON_DEG + moonPerigee;
    // The node is already baked into this projection (Schlyter's xeclip/yeclip);
    // adding it again here would double-count it.
    let moonLongitude = _normalizeDegrees(Math.atan2(
        _sinDeg(moonNode) * _cosDeg(moonArgument) + _cosDeg(moonNode) * _sinDeg(moonArgument) * _cosDeg(moonInclination),
        _cosDeg(moonNode) * _cosDeg(moonArgument) - _sinDeg(moonNode) * _sinDeg(moonArgument) * _cosDeg(moonInclination)
    ) / MOON_DEG);

    // Main perturbation terms (evection, variation, yearly equation, …).
    const sunMeanLongitude = _normalizeDegrees(sunMeanAnomaly + sunPerihelion);
    const moonMeanLongitude = 218.316 + 13.176396 * d;
    const meanElongation = moonMeanLongitude - sunMeanLongitude;
    const latitudeArgument = moonMeanLongitude - moonNode;
    moonLongitude = _normalizeDegrees(moonLongitude
        - 1.274 * _sinDeg(moonMeanAnomaly - 2 * meanElongation)
        + 0.658 * _sinDeg(2 * meanElongation)
        - 0.186 * _sinDeg(sunMeanAnomaly)
        - 0.059 * _sinDeg(2 * moonMeanAnomaly - 2 * meanElongation)
        - 0.057 * _sinDeg(moonMeanAnomaly - 2 * meanElongation + sunMeanAnomaly)
        + 0.053 * _sinDeg(moonMeanAnomaly + 2 * meanElongation)
        + 0.046 * _sinDeg(2 * meanElongation - sunMeanAnomaly)
        + 0.041 * _sinDeg(moonMeanAnomaly - sunMeanAnomaly)
        - 0.035 * _sinDeg(meanElongation)
        - 0.031 * _sinDeg(moonMeanAnomaly + sunMeanAnomaly)
        - 0.015 * _sinDeg(2 * latitudeArgument - 2 * meanElongation)
        + 0.011 * _sinDeg(moonMeanAnomaly - 4 * meanElongation));

    // Elongation 0° = new moon, 180° = full moon.
    const elongationDeg = _normalizeDegrees(moonLongitude - sunLongitude);
    const illumination = (1 - Math.cos(elongationDeg * MOON_DEG)) / 2;
    return {
        index: Math.round(elongationDeg / 45) % 8,
        illumination: illumination,
        elongationDeg: elongationDeg,
        ageDays: (elongationDeg / 360) * MOON_SYNODIC_MONTH
    };
}

function moonGlyphFor(index) {
    return MOON_GLYPHS[index] || MOON_GLYPHS[0];
}
