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
