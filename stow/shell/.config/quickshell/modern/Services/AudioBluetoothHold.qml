// While multipoint headphones belong to this PC, an idle PC parks the
// default output on the silent modern.headset-hold sink
// (pipewire.conf.d/60-modern-headset-hold.conf) instead of the speakers.
// Sound that starts here then waits in silence while the headset switches
// back, rather than playing out loud first. The headset belongs here
// while connected, or after it dropped while this PC was parked (the
// other device took it). It is let go when it dropped during playback
// here, or did not return within one reconnect wait.
import Quickshell
import QtQuick
import "../Commons"

QtObject {
    id: hold

    property var audio: null
    property var bt: null
    readonly property string nodeName: "modern.headset-hold"
    property string _addr: ""

    readonly property var connected: {
        const list = Bluetooth.pairedAudio();
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }
    readonly property var headset: {
        const list = Bluetooth.pairedAudio();
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].address) === hold._addr)
                return list[i];
        }
        return null;
    }
    readonly property var node: {
        const a = hold.audio;
        const t = a ? a.trackedNodes : [];
        for (let i = 0; i < t.length; i++) {
            if (hold.isHold(t[i]))
                return t[i];
        }
        return null;
    }
    readonly property bool parked: hold.isHold(hold.audio ? hold.audio.sink : null)
    readonly property bool active: !!(hold.headset && hold.node && hold.audio
        && hold.audio.autoBluetooth && Bluetooth.powered)

    onConnectedChanged: {
        if (hold.connected)
            hold._addr = String(hold.connected.address);
        else if (!hold.parked)
            hold._addr = "";
    }
    // Headphones in the ears and nothing playing here: the speakers stay quiet.
    onActiveChanged: hold._quiet()
    onParkedChanged: hold._check()
    Component.onCompleted: {
        if (hold.connected)
            hold._addr = String(hold.connected.address);
        hold._quiet();
    }

    property Timer reconnect: Timer {
        interval: Math.max(Motion.bluetoothReconnectMs, 1)
        repeat: false
        onTriggered: {
            if (hold.parked)
                hold._addr = "";
        }
    }

    function isHold(n: var): bool {
        if (!n)
            return false;
        void n.ready;
        return String(n.name || "") === hold.nodeName;
    }

    function label(): string {
        return Bluetooth.deviceLabel(hold.headset);
    }

    // The headset's own sink while parked, so pickers show the headset.
    function shown(n: var): var {
        if (!hold.isHold(n) || !hold.audio || !hold.bt)
            return n;
        const sinks = hold.audio.sinks;
        for (let i = 0; i < sinks.length; i++) {
            if (hold.bt.isBluetoothNode(sinks[i]))
                return sinks[i];
        }
        return n;
    }

    function park() {
        if (!hold.active) {
            hold.bt.applyFallback(true);
            return;
        }
        if (hold.parked)
            return;
        hold.audio.setDefaultSink(hold.node);
        Quickshell.execDetached(["wpctl", "set-default", String(hold.node.id)]);
    }

    // Sound started while parked: the headset gets one reconnect wait.
    function expect() {
        if (hold.parked && !reconnect.running)
            reconnect.restart();
    }

    // Headphones connected and nothing playing here: the speakers stay quiet.
    function _quiet() {
        const a = hold.audio;
        if (hold.active && a && !hold.bt.wantSink && !Bluetooth.userSink && !hold.bt.isBluetoothNode(a.sink))
            hold.park();
        hold._check();
    }

    function _check() {
        if (!hold.parked) {
            reconnect.stop();
            return;
        }
        if (!hold.active)
            Qt.callLater(() => hold.bt.applyFallback(true));
    }
}
