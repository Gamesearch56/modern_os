// Build one taskbar row per application (group windows; skip Wine helpers).
.pragma library

var SKIP_CLASS = {
    "conhost.exe": true,
    "winedbg": true,
    "wineboot.exe": true,
    "wineserver": true,
    "winedevice.exe": true,
    "explorer.exe": true,
    "svchost.exe": true,
    "rpcss.exe": true,
    "plugplay.exe": true,
    "services.exe": true,
    "tabtip.exe": true,
    "xalia.exe": true
};

function normClass(c) {
    return String(c || "").toLowerCase().replace(/\.desktop$/i, "").trim();
}

function groupKey(cls, desktopId) {
    var id = String(desktopId || "").replace(/\.desktop$/i, "").toLowerCase();
    if (id.length >= 2)
        return "id:" + id;
    var c = normClass(cls);
    if (c.length)
        return "cls:" + c;
    return "";
}

function skipWindowClass(cls) {
    var c = normClass(cls);
    if (!c.length || c.indexOf("quickshell") !== -1)
        return true;
    return !!SKIP_CLASS[c];
}

function addPid(g, v) {
    var n = Number(v || 0);
    if (n <= 1)
        return;
    if (g.pids.indexOf(n) === -1)
        g.pids.push(n);
    if (!g.pid)
        g.pid = n;
}

function build(wins, trayOrphans, trayPidsOf, procs, resolveIcon) {
    var groups = {};
    var order = [];

    function ensure(key) {
        if (!groups[key]) {
            groups[key] = {
                kind: "window",
                address: "",
                addresses: [],
                title: "",
                cls: "",
                icon: "",
                iconUrl: "",
                wsId: 0,
                background: true,
                activated: false,
                item: null,
                desktopId: "",
                pid: 0,
                pids: []
            };
            order.push(key);
        }
        return groups[key];
    }

    var i;
    for (i = 0; i < wins.length; i++) {
        var t = wins[i];
        if (!t)
            continue;
        var ipc = t.lastIpcObject || ({});
        var cls = String(ipc.class || t.class || "");
        if (skipWindowClass(cls))
            continue;
        var key = groupKey(cls, "") || ("cls:" + normClass(cls));
        var g = ensure(key);
        var addr = String(t.address || ipc.address || "");
        if (addr.length && g.addresses.indexOf(addr) === -1)
            g.addresses.push(addr);
        if (!g.address.length)
            g.address = addr;
        var title = String(t.title || ipc.class || cls);
        var wsId = t.workspace ? Number(t.workspace.id) : 0;
        var hidden = !!(ipc.hidden === true || ipc.mapped === false);
        var activated = t.activated === true;
        if (activated || !g.title.length)
            g.title = title;
        if (!g.cls.length)
            g.cls = cls || "application-x-executable";
        if (!g.icon.length)
            g.icon = resolveIcon(String(ipc.class || t.class || ipc.initialClass || ""));
        if (wsId > 0 && (activated || !g.wsId))
            g.wsId = wsId;
        if (!(wsId < 0 || hidden))
            g.background = false;
        if (activated)
            g.activated = true;
        addPid(g, ipc.pid);
    }

    for (i = 0; i < trayOrphans.length; i++) {
        var it = trayOrphans[i];
        var pids = trayPidsOf(it) || [];
        if (!pids.length)
            continue;
        var trayTitle = String(it.title || it.tooltipTitle || it.id || "");
        key = groupKey(trayTitle, "") || ("tray:" + trayTitle.toLowerCase());
        if (groups[key] && groups[key].kind === "window") {
            g = groups[key];
            for (var p = 0; p < pids.length; p++)
                addPid(g, pids[p]);
            continue;
        }
        g = ensure(key);
        g.kind = "tray";
        g.title = trayTitle || g.title;
        g.cls = trayTitle || g.cls;
        g.iconUrl = String(it.icon || "");
        g.background = true;
        g.item = it;
        for (var q = 0; q < pids.length; q++)
            addPid(g, pids[q]);
    }

    for (i = 0; i < procs.length; i++) {
        var app = procs[i];
        var appPids = app.pids || [];
        if (!appPids.length)
            continue;
        var desktopId = String(app.id || "");
        key = groupKey(String(app.class || app.icon || ""), desktopId)
            || ("proc:" + desktopId.toLowerCase());
        if (groups[key]) {
            g = groups[key];
            for (var r = 0; r < appPids.length; r++)
                addPid(g, appPids[r]);
            if (!g.desktopId.length)
                g.desktopId = desktopId;
            continue;
        }
        g = ensure(key);
        g.kind = "process";
        g.title = String(app.name || app.id || "");
        g.cls = String(app.icon || app.class || app.id || "");
        g.icon = resolveIcon(String(app.icon || app.class || app.id || ""));
        g.background = true;
        g.desktopId = desktopId;
        for (var s = 0; s < appPids.length; s++)
            addPid(g, appPids[s]);
    }

    var out = [];
    for (i = 0; i < order.length; i++) {
        var e = groups[order[i]];
        if (!e)
            continue;
        if (e.kind === "window" && !e.addresses.length)
            continue;
        if ((e.kind === "tray" || e.kind === "process") && !e.pids.length)
            continue;
        out.push(e);
    }
    return out;
}
