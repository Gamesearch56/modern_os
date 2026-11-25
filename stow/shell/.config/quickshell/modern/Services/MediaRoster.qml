// Instantiator roster for Mpris.players. JS `.values[i]` is empty on a
// cold start even after objectAdded; objectAt() is the live list.
import Quickshell.Services.Mpris
import QtQuick

Instantiator {
    id: root

    signal changed()

    model: Mpris.players
    asynchronous: false
    onObjectAdded: root.changed()
    onObjectRemoved: root.changed()

    delegate: Connections {
        required property var modelData
        target: modelData
        function onIsPlayingChanged() { root.changed(); }
        function onPlaybackStateChanged() { root.changed(); }
        function onIdentityChanged() { root.changed(); }
        function onTrackTitleChanged() { root.changed(); }
        function onTrackArtistChanged() { root.changed(); }
        function onTrackArtUrlChanged() { root.changed(); }
        function onMetadataChanged() { root.changed(); }
        Component.onCompleted: root.changed()
    }

    function list(): var {
        const out = [];
        const n = root.count;
        for (let i = 0; i < n; i++) {
            const c = root.objectAt(i);
            const p = c ? (c.target || c.modelData) : null;
            if (p)
                out.push(p);
        }
        if (out.length)
            return out;
        const vals = Mpris.players ? Mpris.players.values : null;
        if (vals && vals.length)
            return vals;
        return [];
    }
}
