// Multipoint headphones (Pixel Buds, etc.): connect BlueZ audio only
// while the PC is playing, then disconnect when idle so the phone can
// take A2DP. Holding HFP/A2DP with nothing playing keeps the buds on
// the PC and silence on the phone.
import QtQuick
import "../Commons"

QtObject {
    id: root

    property var audio: null
    property var btAuto: null
    readonly property bool enabled: !!(audio && audio.autoBluetooth)

    readonly property string playSig: {
        const a = root.audio;
        if (!a)
            return "";
        const vals = a.streams || [];
        let s = "";
        for (let i = 0; i < vals.length; i++) {
            if (root._isActivePlayback(vals[i]))
                s += String(vals[i].id) + ",";
        }
        return s;
    }

    property bool _wantAudio: false
    property var _tried: ({})
    readonly property bool _powered: Bluetooth.powered

    property Timer idle: Timer {
        interval: Math.max(Motion.bluetoothIdleMs, 1)
        repeat: false
        onTriggered: root._release()
    }

    onEnabledChanged: { root._tried = ({}); root._sync(); }
    on_PoweredChanged: { root._tried = ({}); root._sync(); }
    onPlaySigChanged: root._sync()

    function _isActivePlayback(n: var): bool {
        if (!n)
            return false;
        void n.ready;
        void n.audio;
        void n.properties;
        if (!n.audio || n.audio.muted)
            return false;
        if (n.ready === false)
            return false;
        const p = n.properties || {};
        const mediaClass = String(p["media.class"] || "").toLowerCase();
        if (mediaClass.indexOf("input") !== -1)
            return false;
        const corked = String(p["pulse.corked"] || "").toLowerCase();
        if (corked === "true" || corked === "1")
            return false;
        return true;
    }

    function _playing(): bool {
        return root.playSig.length > 0;
    }

    function _sync() {
        if (!root.enabled) {
            idle.stop();
            root._wantAudio = false;
            return;
        }
        if (root._playing()) {
            idle.stop();
            root._wantAudio = true;
            root._connect();
            return;
        }
        if (!root._wantAudio && !root._anyBtEndpoint())
            return;
        idle.restart();
    }

    // Only on active playback — connecting on mere proximity steals the
    // phone's multipoint A2DP while the PC is idle.
    function _connect() {
        if (!Bluetooth.autoAudio || !Bluetooth.powered)
            return;
        const list = Bluetooth.pairedAudio();
        const tried = Object.assign({}, root._tried);
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const addr = String(d.address);
            if (!d.trusted)
                d.trusted = true;
            if (d.connected || tried[addr])
                continue;
            tried[addr] = true;
            Qt.callLater(() => Bluetooth.connectDevice(d));
        }
        root._tried = tried;
    }

    function _anyBtEndpoint(): bool {
        const a = root.audio;
        if (!a || !root.btAuto)
            return false;
        const sinks = a.sinks || [];
        for (let i = 0; i < sinks.length; i++) {
            if (root.btAuto.isBluetoothNode(sinks[i]))
                return true;
        }
        return false;
    }

    function _release() {
        if (!root.enabled || root._playing())
            return;
        root._wantAudio = false;
        root._tried = ({});
        const list = Bluetooth.pairedAudio();
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                Bluetooth.disconnectDevice(list[i]);
        }
        if (root.btAuto) {
            root.btAuto.applyFallback(true);
            root.btAuto.applyFallback(false);
        }
    }
}
