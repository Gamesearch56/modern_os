.pragma library

// Argv for the Settings file-manager role. Apps owns execDetached.
function localPath(raw) {
    let t = String(raw || "").trim();
    if (!t.length)
        return "";
    if (t.indexOf("file://") === 0) {
        t = t.slice(7);
        try {
            t = decodeURIComponent(t);
        } catch (e) {
        }
    }
    if (t.charAt(0) !== "/")
        return "";
    const parts = t.split("/");
    for (let i = 0; i < parts.length; i++) {
        if (parts[i] === "..")
            return "";
    }
    return t;
}

function argv(desktopId, path, select) {
    const id = String(desktopId || "").replace(/\.desktop$/, "");
    const lower = id.toLowerCase();
    const slash = path.lastIndexOf("/");
    const parent = slash > 0 ? path.slice(0, slash) : path;
    const target = select ? parent : path;
    if (lower.indexOf("dolphin") !== -1)
        return select ? ["dolphin", "--new-window", "--select", path] : ["dolphin", "--new-window", path];
    if (lower.indexOf("nautilus") !== -1)
        return select ? ["nautilus", "--select", path] : ["nautilus", path];
    if (lower.indexOf("nemo") !== -1)
        return ["nemo", path];
    if (lower.indexOf("thunar") !== -1)
        return ["thunar", target];
    if (id.length > 0)
        return ["gtk-launch", id, target];
    return select ? ["dolphin", "--new-window", "--select", path] : ["dolphin", "--new-window", path];
}
