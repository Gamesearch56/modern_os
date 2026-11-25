// MPRIS players. The bar widget never calls playerctl — only this
// singleton. Spotify keeps the bar slot whenever it is open.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    property int _gen: 0

    MediaRoster {
        id: roster
        onChanged: root._bump()
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root._bump(); }
    }

    readonly property var players: Mpris.players
    readonly property var active: {
        void root._gen;
        return root._pickActive();
    }
    readonly property bool hasPlayer: root.active !== null
    readonly property string identity: root.active?.identity ?? ""
    readonly property string desktopEntry: String(root.active?.desktopEntry || "").replace(/\.desktop$/i, "")
    readonly property string trackTitle: root._titleOf(root.active)
    readonly property string trackArtist: root._artistOf(root.active)
    readonly property string trackArtUrl: root.active?.trackArtUrl ?? ""
    readonly property real position: root.active?.position ?? 0
    readonly property real length: root.active?.length ?? 0
    readonly property bool playing: root._isPlaying(root.active)
    readonly property bool anyPlaying: {
        void root._gen;
        const vals = roster.list();
        for (let i = 0; i < vals.length; i++) {
            if (root._isPlaying(vals[i]))
                return true;
        }
        return false;
    }
    readonly property bool canGoNext: root.active?.canGoNext ?? false
    readonly property bool canGoPrevious: root.active?.canGoPrevious ?? false
    readonly property bool canSeek: root.active?.canSeek ?? false
    readonly property bool shuffle: root.active?.shuffle ?? false

    IpcHandler {
        target: "media"
        function dump(): string {
            const vals = roster.list();
            let s = "n=" + vals.length + " has=" + root.hasPlayer
                + " title=[" + root.trackTitle + "] ident=[" + root.identity + "]";
            for (let i = 0; i < vals.length; i++) {
                const p = vals[i];
                s += " | " + String(p?.dbusName || "") + " t=" + root._titleOf(p);
            }
            return s;
        }
        function playPause() { root.togglePlaying(); }
        function play() { root.play(); }
        function pause() { root.pause(); }
        function next() { root.next(); }
        function previous() { root.previous(); }
    }

    function _bump() {
        root._gen++;
    }

    function play() { root.active?.play(); }
    function pause() { root.active?.pause(); }
    function togglePlaying() { root.active?.togglePlaying(); }
    function stop() { root.active?.stop(); }
    function next() { root.active?.next(); }
    function previous() { root.active?.previous(); }
    function seek(seconds: real) {
        if (root.active?.canSeek)
            root.active.seek(seconds);
    }
    function setActive(player: var) {
        if (player)
            player.raise();
    }
    function raise() { root.setActive(root.active); }

    function _isSpotify(player: var): bool {
        const ident = String(player?.identity || "").toLowerCase();
        const dbus = String(player?.dbusName || "").toLowerCase();
        const desk = String(player?.desktopEntry || "").toLowerCase();
        return ident.indexOf("spotify") !== -1 || dbus.indexOf("spotify") !== -1
            || desk.indexOf("spotify") !== -1;
    }

    function _metaStr(player: var, key: string): string {
        const meta = player?.metadata || {};
        const v = meta[key];
        if (v === undefined || v === null)
            return "";
        if (typeof v === "object" && v.length !== undefined)
            return String(v[0] || "").trim();
        return String(v).trim();
    }

    function _titleOf(player: var): string {
        if (!player)
            return "";
        const t = String(player.trackTitle || "").trim();
        if (t.length)
            return t;
        return root._metaStr(player, "xesam:title");
    }

    function _artistOf(player: var): string {
        if (!player)
            return "";
        const a = String(player.trackArtist || "").trim();
        if (a.length)
            return a;
        return root._metaStr(player, "xesam:artist");
    }

    function _isPlaying(player: var): bool {
        if (!player)
            return false;
        const state = player.playbackState;
        const label = String(state).toLowerCase();
        if (state === 2 || label === "paused")
            return false;
        if (state === 1 || label === "playing" || player.isPlaying)
            return true;
        return false;
    }

    function _pickActive(): var {
        void root._gen;
        const vals = roster.list();
        if (!vals || vals.length === 0)
            return null;
        let spotify = null;
        let playing = null;
        let titled = null;
        for (let i = 0; i < vals.length; i++) {
            const p = vals[i];
            if (root._isSpotify(p)) {
                spotify = p;
                continue;
            }
            if (!playing && root._isPlaying(p))
                playing = p;
            if (!titled && root._titleOf(p).length)
                titled = p;
        }
        if (spotify)
            return spotify;
        if (playing)
            return playing;
        if (titled)
            return titled;
        return vals[0];
    }
}
