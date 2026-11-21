#!/usr/bin/env bash
# Services/ics.js: recurring events from Google, Apple and Proton exports
# land on the right days. Runs the QML library under node.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v node >/dev/null 2>&1; then
    printf 'test-calendar-ics: skipped (no node)\n'
    exit 0
fi

TZ=Europe/Berlin node - "$ROOT/stow/shell/.config/quickshell/modern/Services/ics.js" <<'JS'
const fs = require("fs");
const src = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/, "");
const Ics = new Function(src + "; return { parse, instancesInRange };")();
let fail = 0;
const ok = (m) => console.log("test-calendar-ics: ok " + m);
const bad = (m) => { console.error("test-calendar-ics: FAIL " + m); fail = 1; };
const cal = (...ev) => "BEGIN:VCALENDAR\r\n" + ev.map(e => "BEGIN:VEVENT\r\n" + e.join("\r\n") + "\r\nEND:VEVENT\r\n").join("") + "END:VCALENDAR\r\n";
const days = (raw, from, to) => Ics.instancesInRange(Ics.parse(raw), new Date(from), new Date(to)).map(i => i.ymd);
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

let got = days(cal(["UID:a", "SUMMARY:Standup", "DTSTART;TZID=Europe/Berlin:20240101T090000",
    "DTEND;TZID=Europe/Berlin:20240101T091500", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE"]),
    "2026-11-02T00:00:00", "2026-11-09T00:00:00");
same(got, ["2026-11-02", "2026-11-04"]) ? ok("weekly BYDAY shows every listed weekday") : bad("BYDAY: " + got);

got = days(cal(["UID:b", "SUMMARY:Gym", "DTSTART:20200101T060000Z", "DTEND:20200101T070000Z", "RRULE:FREQ=DAILY"]),
    "2026-11-03T00:00:00", "2026-11-04T00:00:00");
same(got, ["2026-11-03"]) ? ok("a daily series from years ago still reaches today") : bad("daily old: " + got);

got = days(cal(["UID:c", "SUMMARY:Review", "DTSTART:20261102T100000", "DTEND:20261102T110000",
    "RRULE:FREQ=DAILY;COUNT=5", "EXDATE:20261104T100000"],
    ["UID:c", "SUMMARY:Review moved", "RECURRENCE-ID:20261105T100000", "DTSTART:20261105T150000", "DTEND:20261105T160000"]),
    "2026-11-01T00:00:00", "2026-11-10T00:00:00");
same(got, ["2026-11-02", "2026-11-03", "2026-11-05", "2026-11-06"]) ? ok("EXDATE and moved occurrences replace the series") : bad("exdate/override: " + got);

got = Ics.instancesInRange(Ics.parse(cal(["UID:d", "SUMMARY:Gone", "STATUS:CANCELLED", "DTSTART:20261103T100000"])),
    new Date("2026-11-01T00:00:00"), new Date("2026-11-10T00:00:00"));
got.length === 0 ? ok("cancelled events stay hidden") : bad("cancelled shown");

got = days(cal(["UID:e", "SUMMARY:Team", "DTSTART:20260105T180000", "DTEND:20260105T190000", "RRULE:FREQ=MONTHLY;BYDAY=1MO"]),
    "2026-11-01T00:00:00", "2026-12-01T00:00:00");
same(got, ["2026-11-02"]) ? ok("monthly first Monday") : bad("1MO: " + got);

got = days(cal(["UID:f", "SUMMARY:Rent", "DTSTART;VALUE=DATE:20260131", "DTEND;VALUE=DATE:20260201", "RRULE:FREQ=MONTHLY"]),
    "2026-02-01T00:00:00", "2026-04-01T00:00:00");
same(got, ["2026-03-31"]) ? ok("the 31st skips months without one") : bad("31st: " + got);

got = days(cal(["UID:g", "SUMMARY:Birthday", "DTSTART;VALUE=DATE:19900815", "DTEND;VALUE=DATE:19900816", "RRULE:FREQ=YEARLY"]),
    "2026-08-01T00:00:00", "2026-09-01T00:00:00");
same(got, ["2026-08-15"]) ? ok("yearly all-day birthday") : bad("yearly: " + got);

process.exit(fail);
JS
printf 'test-calendar-ics: ok\n'
