.pragma library

// Every Imageviewer command, once. The menu, the keyboard, and the
// toolbar read this table; Actions.qml says what each id does. Keys follow
// imv (arrows step, Up/Down and the wheel zoom, h/j/k/l pan, f fullscreen,
// q quit) plus the common Ctrl shortcuts.
const list = [
    { id: "open", key: "viewer.actions.open", icon: "document-open", keys: ["Ctrl+O"], menu: "file" },
    { id: "newWindow", key: "viewer.actions.newWindow", icon: "window-new", keys: ["Ctrl+N"], menu: "file" },
    { id: "reveal", key: "viewer.actions.reveal", icon: "folder-open", keys: ["Ctrl+E"], menu: "file" },
    { id: "copy", key: "viewer.actions.copy", icon: "edit-copy", keys: ["Ctrl+C"], menu: "file", divider: true },
    { id: "copyPath", key: "viewer.actions.copyPath", icon: "edit-copy", keys: ["Ctrl+Shift+C"], menu: "file" },
    { id: "saveRotation", key: "viewer.actions.saveRotation", icon: "document-save", keys: ["Ctrl+S"], menu: "file" },
    { id: "remove", key: "viewer.actions.remove", icon: "list-remove", keys: ["X"], menu: "file", divider: true },
    { id: "trash", key: "viewer.actions.trash", icon: "user-trash", keys: ["Del"], menu: "file", danger: true },
    { id: "close", key: "viewer.actions.close", icon: "window-close", keys: ["Q", "Ctrl+W"], menu: "file" },

    { id: "next", key: "viewer.actions.next", icon: "go-next", keys: ["Right", "Space", "PgDown", "N"], menu: "go" },
    { id: "previous", key: "viewer.actions.previous", icon: "go-previous", keys: ["Left", "Backspace", "PgUp", "P"], menu: "go" },
    { id: "first", key: "viewer.actions.first", icon: "go-first", keys: ["Home", "G, G"], menu: "go" },
    { id: "last", key: "viewer.actions.last", icon: "go-last", keys: ["End", "Shift+G"], menu: "go" },
    { id: "slideshow", key: "viewer.actions.slideshow", icon: "media-playback-start", keys: ["T"], menu: "go", toggle: true },

    { id: "zoomIn", key: "viewer.actions.zoomIn", icon: "zoom-in", keys: ["Up", "+", "=", "I", "Ctrl++"], menu: "view" },
    { id: "zoomOut", key: "viewer.actions.zoomOut", icon: "zoom-out", keys: ["Down", "-", "O", "Ctrl+-"], menu: "view" },
    { id: "fit", key: "viewer.actions.fit", icon: "zoom-fit-best", keys: ["R", "Ctrl+0"], menu: "view" },
    { id: "actual", key: "viewer.actions.actual", icon: "zoom-original", keys: ["A", "1"], menu: "view" },
    { id: "scaling", key: "viewer.actions.scaling", icon: "zoom-select", keys: ["S"], menu: "view" },
    { id: "rotateRight", key: "viewer.actions.rotateRight", icon: "object-rotate-right", keys: ["Shift+R", "]"], menu: "view", divider: true },
    { id: "rotateLeft", key: "viewer.actions.rotateLeft", icon: "object-rotate-left", keys: ["Ctrl+Shift+R", "["], menu: "view" },
    { id: "pause", key: "viewer.actions.pause", icon: "media-playback-pause", keys: ["Ctrl+Space"], menu: "view", toggle: true },
    { id: "info", key: "viewer.actions.info", icon: "dialog-information", keys: ["D", "Ctrl+I"], menu: "view", toggle: true, divider: true },
    { id: "fullscreen", key: "viewer.actions.fullscreen", icon: "view-fullscreen", keys: ["F", "F11"], menu: "view" },
    { id: "leave", key: "viewer.actions.leave", icon: "", keys: ["Escape"], menu: "" },

    { id: "panLeft", key: "viewer.actions.panLeft", icon: "", keys: ["H"], menu: "" },
    { id: "panRight", key: "viewer.actions.panRight", icon: "", keys: ["L"], menu: "" },
    { id: "panUp", key: "viewer.actions.panUp", icon: "", keys: ["K"], menu: "" },
    { id: "panDown", key: "viewer.actions.panDown", icon: "", keys: ["J"], menu: "" }
];

function byId(id) {
    for (let i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i];
    }
    return null;
}

function inMenu(menu) {
    return list.filter(a => a.menu === menu);
}

// The overflow menu: every command that has a menu, grouped in order.
function menuItems() {
    const out = [];
    ["file", "go", "view"].forEach((menu, g) => {
        inMenu(menu).forEach((a, i) => out.push(Object.assign({}, a, { divider: a.divider || (g > 0 && i === 0) })));
    });
    return out;
}

function bindable() {
    return list.filter(a => a.keys.length > 0);
}
