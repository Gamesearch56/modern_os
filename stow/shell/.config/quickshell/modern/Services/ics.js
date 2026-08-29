.pragma library

function unfold(raw) {
    return String(raw || "").replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "");
}

function unescape(s) {
    return String(s || "").replace(/\\n/g, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
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

function parseProps(block) {
    const out = {};
    const lines = block.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const c = line.indexOf(":");
        if (c < 1)
            continue;
        const head = line.slice(0, c);
        const val = line.slice(c + 1);
        const name = head.split(";")[0].toUpperCase();
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

function addFreq(d, freq, interval) {
    const n = new Date(d.getTime());
    const k = Math.max(1, interval);
    if (freq === "DAILY")
        n.setDate(n.getDate() + k);
    else if (freq === "WEEKLY")
        n.setDate(n.getDate() + 7 * k);
    else if (freq === "MONTHLY")
        n.setMonth(n.getMonth() + k);
    else if (freq === "YEARLY")
        n.setFullYear(n.getFullYear() + k);
    else
        n.setDate(n.getDate() + k);
    return n;
}

function expand(ev, rangeStart, rangeEnd) {
    const out = [];
    if (!ev.start)
        return out;
    const dur = ev.end ? (ev.end.getTime() - ev.start.getTime()) : 0;
    const rule = rruleMap(ev.rrule);
    const freq = rule.FREQ || "";
    const interval = Number(rule.INTERVAL || 1);
    let until = null;
    if (rule.UNTIL) {
        const u = parseStamp(rule.UNTIL, false).date;
        if (u)
            until = u;
    }
    const count = rule.COUNT ? Number(rule.COUNT) : 0;
    let cur = new Date(ev.start.getTime());
    let n = 0;
    const cap = count > 0 ? count : 400;
    while (n < cap && cur.getTime() <= rangeEnd.getTime()) {
        if (until && cur.getTime() > until.getTime())
            break;
        const end = dur > 0 ? new Date(cur.getTime() + dur) : null;
        if (end ? end.getTime() >= rangeStart.getTime() : cur.getTime() >= rangeStart.getTime() - 86400000)
            out.push(instance(ev, cur, end));
        n++;
        if (!freq)
            break;
        cur = addFreq(cur, freq, interval);
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
    const chunks = text.split("BEGIN:VEVENT");
    for (let i = 1; i < chunks.length; i++) {
        const block = chunks[i].split("END:VEVENT")[0];
        const p = parseProps(block);
        const startRaw = p.DTSTART ? parseStamp(p.DTSTART.value, /VALUE=DATE/i.test(p.DTSTART.head)) : { date: null, allDay: false };
        const endRaw = p.DTEND ? parseStamp(p.DTEND.value, startRaw.allDay) : { date: null, allDay: startRaw.allDay };
        events.push({
            uid: unescape(p.UID ? p.UID.value : ""),
            summary: unescape(p.SUMMARY ? p.SUMMARY.value : ""),
            description: unescape(p.DESCRIPTION ? p.DESCRIPTION.value : ""),
            start: startRaw.date,
            end: endRaw.date,
            allDay: startRaw.allDay,
            rrule: p.RRULE ? p.RRULE.value : ""
        });
    }
    return events;
}

function instancesInRange(events, rangeStart, rangeEnd) {
    let out = [];
    for (let i = 0; i < events.length; i++)
        out = out.concat(expand(events[i], rangeStart, rangeEnd));
    out.sort((a, b) => a.start.getTime() - b.start.getTime());
    return out;
}
