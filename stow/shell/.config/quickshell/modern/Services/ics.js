.pragma library

const DAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
// Upper bound on generated occurrences per event and range; COUNT and
// the fast-forward below keep real calendars far under it.
const CAP = 1000;

function unfold(raw) {
    return String(raw || "").replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "");
}

function unescape(s) {
    return String(s || "").replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
}

function ymd(d) {
    if (!d || isNaN(d.getTime()))
        return "";
    const m = d.getMonth() + 1;
    const day = d.getDate();
    return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
}

function parseStamp(val, allDay) {
    const v = String(val || "").trim();
    if (/^\d{8}$/.test(v)) {
        const d = new Date(Number(v.slice(0, 4)), Number(v.slice(4, 6)) - 1, Number(v.slice(6, 8)));
        return { date: d, allDay: true };
    }
    const m = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/);
    if (!m)
        return { date: null, allDay: !!allDay };
    const y = Number(m[1]), mo = Number(m[2]) - 1, d = Number(m[3]);
    const h = Number(m[4]), mi = Number(m[5]), s = Number(m[6]);
    const date = m[7] === "Z" ? new Date(Date.UTC(y, mo, d, h, mi, s)) : new Date(y, mo, d, h, mi, s);
    return { date: date, allDay: false };
}

// Last value per property, except EXDATE which may repeat.
function parseProps(block) {
    const out = { EXDATE: [] };
    const lines = block.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const c = line.indexOf(":");
        if (c < 1)
            continue;
        const head = line.slice(0, c);
        const val = line.slice(c + 1);
        const name = head.split(";")[0].toUpperCase();
        if (name === "EXDATE")
            val.split(",").forEach(v => out.EXDATE.push(v));
        else
            out[name] = { value: val, head: head };
    }
    return out;
}

function rruleMap(s) {
    const m = {};
    String(s || "").split(";").forEach(p => {
        const kv = p.split("=");
        if (kv.length >= 2)
            m[kv[0].toUpperCase()] = kv.slice(1).join("=");
    });
    return m;
}

function stampMs(v) {
    const d = parseStamp(v, false).date;
    return d ? d.getTime() : NaN;
}

function shifted(d, unit, n) {
    const x = new Date(d.getTime());
    if (unit === "DAILY")
        x.setDate(x.getDate() + n);
    else if (unit === "WEEKLY")
        x.setDate(x.getDate() + 7 * n);
    else if (unit === "MONTHLY")
        x.setMonth(x.getMonth() + n);
    else
        x.setFullYear(x.getFullYear() + n);
    return x;
}

// BYDAY entries such as "MO" or "-1FR" (last Friday of the month).
function byDays(s) {
    return String(s || "").split(",").map(p => {
        const m = p.trim().toUpperCase().match(/^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/);
        return m ? { nth: m[1] ? Number(m[1]) : 0, day: DAYS.indexOf(m[2]) } : null;
    }).filter(x => x !== null);
}

function withTime(day, from) {
    return new Date(day.getFullYear(), day.getMonth(), day.getDate(),
        from.getHours(), from.getMinutes(), from.getSeconds());
}

// Candidate starts for one period of the rule, in order.
function periodStarts(base, freq, rule, start) {
    const days = byDays(rule.BYDAY);
    if (freq === "WEEKLY" && days.length) {
        const monday = new Date(base.getFullYear(), base.getMonth(), base.getDate() - ((base.getDay() + 6) % 7));
        return days.map(b => withTime(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + ((b.day + 6) % 7)), start))
            .sort((a, b) => a - b);
    }
    if (freq === "MONTHLY" && days.length) {
        const y = base.getFullYear(), mo = base.getMonth();
        const last = new Date(y, mo + 1, 0).getDate();
        const out = [];
        for (let d = 1; d <= last; d++) {
            const dayDate = new Date(y, mo, d);
            for (const b of days) {
                if (dayDate.getDay() !== b.day)
                    continue;
                const nth = Math.ceil(d / 7), fromEnd = -Math.ceil((last - d + 1) / 7);
                if (b.nth === 0 || b.nth === nth || b.nth === fromEnd)
                    out.push(withTime(dayDate, start));
            }
        }
        return out;
    }
    if (freq === "MONTHLY" || freq === "YEARLY") {
        const y = base.getFullYear();
        const mo = freq === "YEARLY" ? start.getMonth() : base.getMonth();
        // The 31st or Feb 29 only exists in some periods; RFC 5545 skips the rest.
        if (start.getDate() > new Date(y, mo + 1, 0).getDate())
            return [];
        return [withTime(new Date(y, mo, start.getDate()), start)];
    }
    return [base];
}

function expand(ev, rangeStart, rangeEnd) {
    const out = [];
    if (!ev.start)
        return out;
    const dur = ev.end ? (ev.end.getTime() - ev.start.getTime()) : 0;
    const rule = rruleMap(ev.rrule);
    const freq = rule.FREQ || "";
    const interval = Math.max(1, Number(rule.INTERVAL || 1));
    const until = rule.UNTIL ? parseStamp(rule.UNTIL, false).date : null;
    const count = rule.COUNT ? Number(rule.COUNT) : 0;
    const skip = ev.skip || ({});
    const emit = (s) => {
        const e = dur > 0 ? new Date(s.getTime() + dur) : null;
        const hit = e ? e.getTime() > rangeStart.getTime() : s.getTime() >= rangeStart.getTime() - 86400000;
        if (hit && s.getTime() <= rangeEnd.getTime() && !skip[s.getTime()])
            out.push(instance(ev, s, e));
    };
    if (!freq) {
        emit(ev.start);
        return out;
    }
    let base = freq === "MONTHLY" || freq === "YEARLY"
        ? new Date(ev.start.getFullYear(), ev.start.getMonth(), 1)
        : new Date(ev.start.getTime());
    // Without COUNT nothing before the range matters: jump straight to it.
    if (!count && (freq === "DAILY" || freq === "WEEKLY")) {
        const span = (freq === "DAILY" ? 1 : 7) * interval * 86400000;
        const behind = Math.floor((rangeStart.getTime() - dur - base.getTime()) / span) - 1;
        if (behind > 0)
            base = shifted(base, freq, behind * interval);
    }
    let n = 0;
    for (let guard = 0; guard < CAP && base.getTime() <= rangeEnd.getTime() + 7 * 86400000; guard++) {
        for (const s of periodStarts(base, freq, rule, ev.start)) {
            if (s.getTime() < ev.start.getTime())
                continue;
            if ((until && s.getTime() > until.getTime()) || (count && n >= count))
                return out;
            n++;
            emit(s);
        }
        base = shifted(base, freq, interval);
    }
    return out;
}

function instance(ev, start, end) {
    return {
        uid: ev.uid,
        summary: ev.summary,
        description: ev.description,
        start: start,
        end: end,
        allDay: ev.allDay,
        ymd: ymd(start),
        when: ev.allDay ? ymd(start) : ""
    };
}

function parse(raw) {
    const text = unfold(raw);
    const events = [];
    const moved = {};
    const chunks = text.split("BEGIN:VEVENT");
    for (let i = 1; i < chunks.length; i++) {
        const p = parseProps(chunks[i].split("END:VEVENT")[0]);
        const uid = unescape(p.UID ? p.UID.value : "");
        // A RECURRENCE-ID event replaces (or cancels) one occurrence of
        // the series with the same UID.
        if (p["RECURRENCE-ID"]) {
            const at = stampMs(p["RECURRENCE-ID"].value);
            if (!isNaN(at))
                (moved[uid] = moved[uid] || {})[at] = true;
        }
        if (p.STATUS && p.STATUS.value.trim().toUpperCase() === "CANCELLED")
            continue;
        const startRaw = p.DTSTART ? parseStamp(p.DTSTART.value, /VALUE=DATE/i.test(p.DTSTART.head)) : { date: null, allDay: false };
        const endRaw = p.DTEND ? parseStamp(p.DTEND.value, startRaw.allDay) : { date: null, allDay: startRaw.allDay };
        const skip = {};
        p.EXDATE.forEach(v => {
            const at = stampMs(v);
            if (!isNaN(at))
                skip[at] = true;
        });
        events.push({
            uid: uid,
            summary: unescape(p.SUMMARY ? p.SUMMARY.value : ""),
            description: unescape(p.DESCRIPTION ? p.DESCRIPTION.value : ""),
            start: startRaw.date,
            end: endRaw.date,
            allDay: startRaw.allDay,
            rrule: p["RECURRENCE-ID"] ? "" : (p.RRULE ? p.RRULE.value : ""),
            skip: skip
        });
    }
    for (const ev of events) {
        const m = moved[ev.uid];
        if (ev.rrule && m)
            for (const at in m)
                ev.skip[at] = true;
    }
    return events;
}

function startMs(ev) {
    if (!ev || !ev.start || isNaN(ev.start.getTime()))
        return 0;
    return ev.start.getTime();
}

function instancesInRange(events, rangeStart, rangeEnd) {
    let out = [];
    for (let i = 0; i < events.length; i++)
        out = out.concat(expand(events[i], rangeStart, rangeEnd));
    out.sort((a, b) => {
        if (!!a.allDay !== !!b.allDay)
            return a.allDay ? -1 : 1;
        const dt = startMs(a) - startMs(b);
        if (dt !== 0)
            return dt;
        return String(a.summary || "").localeCompare(String(b.summary || ""));
    });
    return out;
}
