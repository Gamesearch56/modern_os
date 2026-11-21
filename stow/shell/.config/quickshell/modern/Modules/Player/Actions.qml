import QtQuick
import "../../Commons"
import "../../Services"
import "actions.js" as ActionList
import "playops.js" as Ops

// What each command in actions.js does, and when it can. The control bar,
// the menus and the keys call run(id); none of them reach into the playback.
// A change you cannot see (volume, speed, a seek) is told on the OSD.
QtObject {
    id: root

    property var playback: null
    property var window: null
    property var osd: null

    readonly property bool _loaded: !PlayerDoc.empty && !!root.playback && root.playback.ready

    function def(id: string): var {
        return ActionList.byId(id);
    }

    function menuItems(): var {
        return ActionList.menuItems();
    }

    function speedItems(): var {
        return ActionList.speedItems(Ops.speeds, Ops.speedLabel);
    }

    function audioItems(): var {
        return root.playback ? ActionList.trackItems("audio", root.playback.audioTracks, false) : [];
    }

    function subtitleItems(): var {
        return root.playback ? ActionList.trackItems("subtitles", root.playback.subtitleTracks, true) : [];
    }

    function enabled(id: string): bool {
        const c = ActionList.choice(id);
        if (c)
            return root._loaded;
        switch (id) {
        case "open":
        case "newWindow":
        case "close":
        case "fullscreen":
        case "leave":
        case "loop":
        case "mute":
        case "volumeUp":
        case "volumeDown":
            return true;
        case "next":
        case "previous":
            return PlayerDoc.count > 1;
        case "reveal":
        case "copyPath":
            return !PlayerDoc.empty;
        case "screenshot":
            return root._loaded && root.playback.hasVideo && !PlayerDoc.busy;
        case "subtitles":
            return root._loaded && root.playback.subtitleTracks.length > 0;
        case "audioTrack":
            return root._loaded && root.playback.audioTracks.length > 1;
        default:
            return root._loaded;
        }
    }

    function checked(id: string): bool {
        const c = ActionList.choice(id);
        if (c && root.playback) {
            if (c.group === "speed")
                return Math.abs(root.playback.rate - c.value) < 1e-3;
            if (c.group === "audio")
                return root.playback.activeAudio === c.value;
            if (c.group === "subtitles")
                return root.playback.activeSubtitle === c.value;
        }
        if (id === "loop")
            return PlayerPrefs.loop;
        if (id === "mute")
            return PlayerPrefs.muted;
        if (id === "fullscreen")
            return !!root.window && root.window.fullscreen;
        return false;
    }

    function _say(key: string, params: var) {
        if (root.osd)
            root.osd.show(I18n.t(key, params || ({})));
    }

    function _speed(r: real) {
        root.playback.setRate(r);
        root._say("player.speed", { speed: Ops.speedLabel(r) });
    }

    function _volume() {
        if (PlayerPrefs.muted)
            root._say("player.osd.muted", null);
        else
            root._say("player.osd.volume", { percent: Ops.percent(PlayerPrefs.volume) });
    }

    function _seek(seconds: int) {
        const s = root.playback;
        const to = Ops.seekTarget(s.position, seconds * 1000, s.duration);
        s.seekTo(to);
        root._say("player.time", { position: Ops.clock(to), duration: Ops.clock(s.duration) });
    }

    function _audio(i: int) {
        root.playback.setAudio(i);
        root._say("player.osd.audio", { name: root.playback.trackName(root.playback.audioTracks, i) });
    }

    function _subtitle(i: int) {
        root.playback.setSubtitle(i);
        if (i < 0)
            root._say("player.osd.subtitlesOff", null);
        else
            root._say("player.osd.subtitles", { name: root.playback.trackName(root.playback.subtitleTracks, i) });
    }

    function _choose(c: var) {
        if (c.group === "speed")
            root._speed(c.value);
        else if (c.group === "audio")
            root._audio(c.value);
        else if (c.group === "subtitles")
            root._subtitle(c.value);
    }

    function run(id: string) {
        if (!root.enabled(id))
            return;
        const s = root.playback;
        const c = ActionList.choice(id);
        if (c) {
            root._choose(c);
            return;
        }
        switch (id) {
        case "open": root.window.module.choose(); break;
        case "newWindow": PlayerDoc.openWindow(); break;
        case "reveal": PlayerDoc.reveal(); break;
        case "copyPath": PlayerDoc.copyPath(); break;
        case "screenshot": PlayerDoc.screenshot(s.position); break;
        case "close": root.window.module.quit(); break;
        case "playPause": s.togglePlay(); break;
        case "forward": root._seek(PlayerPrefs.seekSeconds); break;
        case "back": root._seek(-PlayerPrefs.seekSeconds); break;
        case "jumpForward": root._seek(PlayerPrefs.jumpSeconds); break;
        case "jumpBack": root._seek(-PlayerPrefs.jumpSeconds); break;
        case "nextFrame": s.step(1); break;
        case "previousFrame": s.step(-1); break;
        case "next": PlayerDoc.next(); break;
        case "previous": PlayerDoc.previous(); break;
        case "loop":
            PlayerPrefs.setLoop(!PlayerPrefs.loop);
            root._say(PlayerPrefs.loop ? "player.osd.loopOn" : "player.osd.loopOff", null);
            break;
        case "faster": root._speed(Ops.stepSpeed(s.rate, 1)); break;
        case "slower": root._speed(Ops.stepSpeed(s.rate, -1)); break;
        case "normalSpeed": root._speed(1); break;
        case "volumeUp": PlayerPrefs.nudgeVolume(1); root._volume(); break;
        case "volumeDown": PlayerPrefs.nudgeVolume(-1); root._volume(); break;
        case "mute": PlayerPrefs.setMuted(!PlayerPrefs.muted); root._volume(); break;
        case "subtitles": root._subtitle(Ops.cycleTrack(s.activeSubtitle, s.subtitleTracks.length, true)); break;
        case "audioTrack": root._audio(Ops.cycleTrack(s.activeAudio, s.audioTracks.length, false)); break;
        case "fullscreen": PlayerDoc.toggleFullscreen(); break;
        case "leave":
            if (root.window.fullscreen)
                PlayerDoc.toggleFullscreen();
            break;
        default: break;
        }
    }

    function keyLabel(id: string): string {
        const a = ActionList.byId(id);
        return a && a.keys.length ? KeyLabel.of(a.keys[0]) : "";
    }
}
