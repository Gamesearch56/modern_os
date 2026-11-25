.pragma library

// Where a link inside a document points. Relative links resolve against
// the folder of the document they sit in, like on a web page.

function isExternal(link) {
    return /^[a-z][a-z0-9+.-]*:/i.test(String(link || "")) && !/^file:/i.test(link);
}

function _normalize(path) {
    const out = [];
    const parts = path.split("/");
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i];
        if (!p.length || p === ".")
            continue;
        if (p === "..")
            out.pop();
        else
            out.push(p);
    }
    return "/" + out.join("/");
}

function _plain(html) {
    return String(html || "").replace(/<[^>]*>/g, "")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
        .replace(/&#39;/g, "'").replace(/&nbsp;/g, "\u00a0").replace(/&amp;/g, "&");
}

// Links the keyboard can step through, as { href, start, end } in the
// shown text. Only links that go somewhere: the web, or another document.
// Each label is looked up after the previous one, so repeated labels
// land on their own occurrence.
function stops(html, shown) {
    const out = [];
    const re = /<a\s+href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
    let from = 0;
    let m;
    while ((m = re.exec(String(html || ""))) !== null) {
        const href = _plain(m[1]);
        const label = _plain(m[2]);
        const at = label.length ? shown.indexOf(label, from) : -1;
        if (at < 0)
            continue;
        from = at + label.length;
        if (isExternal(href) || /\.md(#|$)/i.test(href))
            out.push({ href: href, start: at, end: at + label.length });
    }
    return out;
}

// Absolute file path for a relative or file: link, without its #anchor;
// "" for a bare anchor.
function resolve(fromPath, link) {
    let target = String(link || "");
    if (/^file:/i.test(target))
        target = decodeURIComponent(target.replace(/^file:\/\//i, ""));
    const hash = target.indexOf("#");
    if (hash >= 0)
        target = target.slice(0, hash);
    if (!target.length)
        return "";
    if (target.charAt(0) === "/")
        return _normalize(target);
    const dir = String(fromPath || "/").replace(/\/[^/]*$/, "");
    return _normalize(dir + "/" + decodeURIComponent(target));
}
