.pragma library
// Plain-text helpers for the Texteditor: find, replace, and line math.
// No QML here, so scripts/test-editor.sh can run them under node.
// Case-insensitive search uses a RegExp "i" flag instead of lowercasing
// the text: lowercasing can change the length and shift every match.

function _pattern(needle, matchCase) {
    const escaped = String(needle).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(escaped, matchCase ? "g" : "gi");
}

// The next match from `from`: forward starts at `from`, backward ends
// before it. Wraps once when asked. Returns { start, end } or null.
function find(text, needle, from, forward, matchCase, wrap) {
    const body = String(text || "");
    if (!needle || !needle.length)
        return null;
    const re = _pattern(needle, matchCase);
    const at = Math.max(0, Math.min(body.length, Number(from) || 0));
    if (forward) {
        re.lastIndex = at;
        let m = re.exec(body);
        if (!m && wrap && at > 0) {
            re.lastIndex = 0;
            m = re.exec(body);
        }
        return m ? { start: m.index, end: m.index + m[0].length } : null;
    }
    let before = null;
    let last = null;
    let m;
    re.lastIndex = 0;
    while ((m = re.exec(body)) !== null) {
        const hit = { start: m.index, end: m.index + m[0].length };
        if (hit.end <= at)
            before = hit;
        last = hit;
        if (m[0].length === 0)
            re.lastIndex++;
    }
    return before || (wrap ? last : null);
}

function count(text, needle, matchCase) {
    if (!needle || !needle.length)
        return 0;
    const hits = String(text || "").match(_pattern(needle, matchCase));
    return hits ? hits.length : 0;
}

// The replacement is literal: "$1" or "$&" stay as typed.
function replaceAll(text, needle, replacement, matchCase) {
    const body = String(text || "");
    if (!needle || !needle.length)
        return { text: body, count: 0 };
    let n = 0;
    const out = body.replace(_pattern(needle, matchCase), () => {
        n++;
        return String(replacement);
    });
    return { text: out, count: n };
}

// 1-based line and column of a cursor position.
function lineCol(text, pos) {
    const body = String(text || "");
    const at = Math.max(0, Math.min(body.length, Number(pos) || 0));
    let line = 1;
    let i = body.indexOf("\n");
    while (i !== -1 && i < at) {
        line++;
        i = body.indexOf("\n", i + 1);
    }
    const start = body.lastIndexOf("\n", at - 1) + 1;
    return { line: line, column: at - start + 1 };
}

function lineCount(text) {
    const body = String(text || "");
    let n = 1;
    let i = body.indexOf("\n");
    while (i !== -1) {
        n++;
        i = body.indexOf("\n", i + 1);
    }
    return n;
}

// Start of a 1-based line, clamped to the text.
function lineStart(text, line) {
    const body = String(text || "");
    const want = Math.max(1, Math.floor(Number(line) || 1));
    let at = 0;
    for (let n = 1; n < want; n++) {
        const i = body.indexOf("\n", at);
        if (i === -1)
            break;
        at = i + 1;
    }
    return at;
}
