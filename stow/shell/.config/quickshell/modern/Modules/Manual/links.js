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
