// Shared clock/date formatting for the bar clock and control-center
// header. Tokens stay on language.dateFormat / timeFormat.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function formatDate(d: var, pattern: string): string {
        if (!d)
            return "";
        const dd = root.pad(d.getDate());
        const mm = root.pad(d.getMonth() + 1);
        const yyyy = String(d.getFullYear());
        const p = pattern || "DD.MM.YYYY";
        if (p === "YYYY-MM-DD")
            return yyyy + "-" + mm + "-" + dd;
        if (p === "MM/DD/YYYY")
            return mm + "/" + dd + "/" + yyyy;
        return dd + "." + mm + "." + yyyy;
    }

    function formatTime(d: var, pattern: string, showSeconds: bool): string {
        if (!d)
            return "";
        const p = pattern || "HH:mm";
        const sec = showSeconds ? (":" + root.pad(d.getSeconds())) : "";
        if (p === "hh:mm a") {
            let h = d.getHours();
            const am = h < 12;
            h = h % 12;
            if (h === 0)
                h = 12;
            return root.pad(h) + ":" + root.pad(d.getMinutes()) + sec + (am ? " AM" : " PM");
        }
        return root.pad(d.getHours()) + ":" + root.pad(d.getMinutes()) + sec;
    }

    function weekday(d: var): string {
        if (!d)
            return "";
        const keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        return I18n.t("time.weekday." + keys[d.getDay()]);
    }

    function weekdayIndex(i: int): string {
        const keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        const k = keys[((i % 7) + 7) % 7];
        return I18n.t("time.weekday." + k);
    }

    function monthTitle(year: int, month: int): string {
        const keys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        const name = I18n.t("time.month." + keys[((month % 12) + 12) % 12]);
        return name + " " + year;
    }

    function clockLabel(d: var, dateFmt: string, timeFmt: string, showSeconds: bool, showWeekday: bool): string {
        const dateStr = root.formatDate(d, dateFmt);
        const timeStr = root.formatTime(d, timeFmt, showSeconds);
        const head = showWeekday ? (root.weekday(d) + " ") : "";
        return head + dateStr + "  " + timeStr;
    }
}
