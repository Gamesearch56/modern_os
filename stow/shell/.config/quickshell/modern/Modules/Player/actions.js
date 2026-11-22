.pragma library

// Every Mediaplayer command, once. The menu, the keyboard, and the control
// bar read this table; Actions.qml says what each id does. Keys follow mpv
// (Space/K pause, arrows seek, [ ] speed, 9 0 volume, m mute, f fullscreen,
// j/v subtitles, # audio track, L repeat, s frame, . , frame step,
// < > files, q quit) plus the common Ctrl shortcuts.
const list = [
    { id: "open", key: "player.actions.open", icon: "document-open", keys: ["Ctrl+O"], menu: "file" },
    { id: "newWindow", key: "player.actions.newWindow", icon: "window-new", keys: ["Ctrl+N"], menu: "file" },
    { id: "reveal", key: "player.actions.reveal", icon: "folder-open", keys: ["Ctrl+E"], menu: "file" },
    { id: "copyPath", key: "player.actions.copyPath", icon: "edit-copy", keys: ["Ctrl+Shift+C"], menu: "file" },
    { id: "screenshot", key: "player.actions.screenshot", icon: "camera-photo", keys: ["S"], menu: "file", divider: true },
    { id: "close", key: "player.actions.close", icon: "window-close", keys: ["Q", "Ctrl+W"], menu: "file", divider: true },

    { id: "playPause", key: "player.actions.pause", icon: "media-playback-pause", keys: ["Space", "K", "P"], menu: "" },
    { id: "forward", key: "player.actions.forward", icon: "media-seek-forward", keys: ["Right"], menu: "play" },
    { id: "back", key: "player.actions.back", icon: "media-seek-backward", keys: ["Left"], menu: "play" },
    { id: "jumpForward", key: "player.actions.jumpForward", icon: "", keys: ["Up"], menu: "play" },
    { id: "jumpBack", key: "player.actions.jumpBack", icon: "", keys: ["Down"], menu: "play" },
    { id: "nextFrame", key: "player.actions.nextFrame", icon: "", keys: ["."], menu: "play", divider: true },
    { id: "previousFrame", key: "player.actions.previousFrame", icon: "", keys: [","], menu: "play" },
    { id: "next", key: "player.actions.next", icon: "media-skip-forward", keys: [">", "N", "PgDown"], menu: "play", divider: true },
    { id: "previous", key: "player.actions.previous", icon: "media-skip-backward", keys: ["<", "Shift+N", "PgUp"], menu: "play" },
    { id: "loop", key: "player.actions.loop", icon: "media-playlist-repeat", keys: ["Shift+L"], menu: "play", toggle: true },

    { id: "faster", key: "player.actions.faster", icon: "", keys: ["]"], menu: "sound", divider: true },
    { id: "slower", key: "player.actions.slower", icon: "", keys: ["["], menu: "sound" },
    { id: "normalSpeed", key: "player.actions.normalSpeed", icon: "", keys: ["Backspace"], menu: "sound" },
    { id: "volumeUp", key: "player.actions.volumeUp", icon: "audio-volume-high", keys: ["0", "*", "Ctrl+Up"], menu: "sound", divider: true },
    { id: "volumeDown", key: "player.actions.volumeDown", icon: "audio-volume-low", keys: ["9", "/", "Ctrl+Down"], menu: "sound" },
    { id: "mute", key: "player.actions.mute", icon: "audio-volume-muted", keys: ["M"], menu: "sound", toggle: true },
    { id: "subtitles", key: "player.actions.subtitles", icon: "media-view-subtitles", keys: ["J", "V"], menu: "sound", divider: true },
    { id: "audioTrack", key: "player.actions.audioTrack", icon: "audio-x-generic", keys: ["#"], menu: "sound" },
    { id: "fullscreen", key: "player.actions.fullscreen", icon: "view-fullscreen", keys: ["F", "F11"], menu: "sound", divider: true },
    { id: "leave", key: "player.actions.leave", icon: "", keys: ["Escape"], menu: "" }
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
    ["file", "play", "sound"].forEach((menu, g) => {
        inMenu(menu).forEach((a, i) => out.push(Object.assign({}, a, { divider: a.divider || (g > 0 && i === 0) })));
    });
    return out;
}

function bindable() {
    return list.filter(a => a.keys.length > 0);
}

// Choice menus: "speed:1.5", "audio:0", "subtitles:-1". The id carries the
// choice so Actions.run stays the one place that acts.
function choice(id) {
    const at = String(id).indexOf(":");
    if (at < 0)
        return null;
    return { group: id.slice(0, at), value: Number(id.slice(at + 1)) };
}

function speedItems(speeds, labelOf) {
    return speeds.map(s => s === 1
        ? { id: "speed:1", key: "player.menu.normal" }
        : { id: "speed:" + s, key: "player.speed", params: { speed: labelOf(s) } });
}

// tracks: [{ label }]; an empty label reads "Track n".
function trackItems(group, tracks, withOff) {
    const out = withOff ? [{ id: group + ":-1", key: "player.menu.off" }] : [];
    tracks.forEach((t, i) => out.push(t.label.length
        ? { id: group + ":" + i, value: t.label }
        : { id: group + ":" + i, key: "player.menu.track", params: { number: i + 1 } }));
    return out;
}
