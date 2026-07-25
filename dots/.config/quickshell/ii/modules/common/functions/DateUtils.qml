pragma Singleton
import Quickshell
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    // Qt uses a 12h clock when the format contains an unquoted am/pm field (a, A, ap or AP).
    // Text inside single quotes is fixed text, so it must not count.
    function is12HourTimeFormat(format) {
        if (!format)
            return false;

        return /[aA]/.test(String(format).replace(/'[^']*'/g, ""));
    }

    // Returns "" when the format is usable, otherwise an error code the UI turns into
    // a translated message. A code rather than a string keeps this file free of a
    // qs.services dependency (Translation lives there, and services import common).
    function dateTimeFormatError(format) {
        const trimmed = String(format ?? "").trim();
        if (trimmed.length === 0)
            return "empty";

        if ((trimmed.match(/'/g) ?? []).length % 2 !== 0)
            return "unclosedQuote";

        // Qt echoes characters it doesn't recognize verbatim, so an unchanged result means
        // the string contains no actual date/time fields and would render as dead text.
        if (Qt.locale().toString(new Date(), trimmed) === trimmed)
            return "noFields";

        return "";
    }

    function isValidDateTimeFormat(format) {
        return root.dateTimeFormatError(format).length === 0;
    }

    function syncHyprlockTimeFormat(format) {
        const configPath = FileUtils.trimFileProtocol(Directories.config) + "/hypr/hyprlock.conf";
        const twelveHour = root.is12HourTimeFormat(format);
        const from = twelveHour ? "TIME" : "TIME12";
        const to = twelveHour ? "TIME12" : "TIME";
        // --follow-symlinks keeps dotfile symlinks intact; anchoring on $ avoids mangling
        // unrelated words such as MYTIME.
        const script = `[ -f '${configPath}' ] || exit 0; sed -i --follow-symlinks 's/\\$${from}\\b/$${to}/g' '${configPath}'`;
        Quickshell.execDetached(["bash", "-c", script]);
    }

    function getFirstDayOfWeek(date, firstDay = 1) {
        const d = new Date(date); // Copy
        const day = d.getDay();   // 0 = Sunday, 1 = Monday, ..., 6 = Saturday

        // Calculate difference to firstDay
        const diff = (day - firstDay + 7) % 7;
        d.setDate(d.getDate() - diff);
        return d;
    }

    function sameDate(d1, d2) {
        return (d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate());
    }

    function getIthDayDateOfSameWeek(date, i, firstDay = 1) {
        const firstDayDate = root.getFirstDayOfWeek(date, firstDay);
        const targetDate = new Date(firstDayDate);
        targetDate.setDate(firstDayDate.getDate() + i);
        return targetDate;
    }
}
