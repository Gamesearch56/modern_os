// MPRIS players. Spotify and anything else that speaks the spec. The
// media widget never calls playerctl — only this singleton.
pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property var players: Mpris.players
    readonly property var active: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool hasPlayer: root.active !== null
    readonly property string identity: root.active?.identity ?? ""
    readonly property string trackTitle: root.active?.trackTitle ?? ""
    readonly property string trackArtist: root.active?.trackArtist ?? ""
    readonly property string trackAlbum: root.active?.trackAlbum ?? ""
    readonly property string trackArtUrl: root.active?.trackArtUrl ?? ""
    readonly property real position: root.active?.position ?? 0
    readonly property real length: root.active?.length ?? 0
    readonly property bool playing: root.active?.isPlaying ?? false
    readonly property bool canPlay: root.active?.canPlay ?? false
    readonly property bool canPause: root.active?.canPause ?? false
    readonly property bool canGoNext: root.active?.canGoNext ?? false
    readonly property bool canGoPrevious: root.active?.canGoPrevious ?? false
    readonly property bool canSeek: root.active?.canSeek ?? false
    readonly property int loopState: root.active?.loopState ?? 0
    readonly property bool shuffle: root.active?.shuffle ?? false

    function play() {
        root.active?.play();
    }
    function pause() {
        root.active?.pause();
    }
    function togglePlaying() {
        root.active?.togglePlaying();
    }
    function stop() {
        root.active?.stop();
    }
    function next() {
        root.active?.next();
    }
    function previous() {
        root.active?.previous();
    }
    function seek(seconds: real) {
        if (root.active?.canSeek)
            root.active.seek(seconds);
    }
    function setPosition(seconds: real) {
        if (root.active)
            root.active.position = seconds;
    }
    function setShuffle(on: bool) {
        if (root.active)
            root.active.shuffle = on;
    }
    function cycleLoop() {
        if (!root.active)
            return;
        root.active.loopState = (root.active.loopState + 1) % 3;
    }
    function openUri(uri: string) {
        root.active?.openUri(uri);
    }
    function launchSpotify() {
        Quickshell.execDetached(["spotify-launcher"]);
    }
    function setActive(player: var) {
        if (player)
            player.raise();
    }
    function raise() {
        root.setActive(root.active);
    }
}
