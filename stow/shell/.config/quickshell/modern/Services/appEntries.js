.pragma library

// A second desktop file for the same ModernOS program is not another
// app. It is usually named only imageviewer, mediaplayer, or editor.
// The modern.* entry is the one the default-app list should offer.
function keep(stem, execString, modernStems) {
    const s = String(stem || "");
    if (s.indexOf("modern.") === 0)
        return true;
    const have = modernStems || {};
    if (have["modern." + s])
        return false;
    const word = String(execString || "").trim().split(/\s+/)[0].split("/").pop();
    if (word.indexOf("modern-") === 0) {
        const id = "modern." + word.substring("modern-".length);
        if (have[id])
            return false;
    }
    return true;
}

function _execBase(execString) {
    return String(execString || "").trim().split(/\s+/)[0].split("/").pop().toLowerCase();
}

// A raw id ("org.proton.mail", "thunderbird") is a worse label than
// the name the desktop file gives the same program.
function _rawTitle(stem, title) {
    const t = String(title || "").trim();
    if (!t.length)
        return true;
    const low = t.toLowerCase();
    if (low === stem || t.indexOf(".") !== -1)
        return true;
    return low === t && t.indexOf(" ") === -1;
}

// Several desktop files for one program: the store id, the flatpak id,
// and an unofficial client of the same service.
function family(stem, title, execString) {
    const s = String(stem || "").toLowerCase();
    const last = s.split(".").pop().replace(/-(stable|bin|desktop|browser|esr|beta|git)$/, "");
    const blob = (s + " " + last + " " + String(title || "") + " " + _execBase(execString)).toLowerCase();
    if (blob.indexOf("wasistlos") !== -1 || blob.indexOf("zapzap") !== -1 || blob.indexOf("whatsapp") !== -1)
        return "whatsapp";
    if (blob.indexOf("thunderbird") !== -1)
        return "thunderbird";
    if (blob.indexOf("proton") !== -1 && blob.indexOf("mail") !== -1)
        return "proton-mail";
    if (blob.indexOf("proton") !== -1 && blob.indexOf("calendar") !== -1)
        return "proton-calendar";
    return last;
}

function _score(stem, title, fam) {
    let score = 0;
    if (stem.indexOf("modern.") === 0)
        score += 100;
    if (fam === "whatsapp" && stem === "whatsapp")
        score += 80;
    if ((fam === "proton-mail" && stem === "proton-mail")
            || (fam === "proton-calendar" && stem === "proton-calendar")
            || (fam === "thunderbird" && stem === "thunderbird"))
        score += 40;
    if (!_rawTitle(stem, title))
        score += 20;
    if (stem.indexOf(".") === -1)
        score += 5;
    return score;
}

// One row per program. The shipped app wins over a second desktop id
// or an unofficial client of the same service.
function pick(rows) {
    const list = rows || [];
    const modern = {};
    for (let i = 0; i < list.length; i++) {
        const stem = String(list[i].value || "").replace(/\.desktop$/, "").toLowerCase();
        if (stem.indexOf("modern.") === 0)
            modern[stem] = true;
    }
    const best = {};
    const order = [];
    for (let i = 0; i < list.length; i++) {
        const row = list[i];
        const stem = String(row.value || "").replace(/\.desktop$/, "").toLowerCase();
        if (!keep(stem, row._exec, modern))
            continue;
        const fam = family(stem, row.titleValue, row._exec);
        const prev = best[fam];
        if (!prev) {
            best[fam] = row;
            order.push(fam);
            continue;
        }
        if (_score(stem, row.titleValue, fam) > _score(
                String(prev.value || "").replace(/\.desktop$/, "").toLowerCase(), prev.titleValue, fam))
            best[fam] = row;
    }
    const out = [];
    for (let i = 0; i < order.length; i++)
        out.push(best[order[i]]);
    return out;
}
