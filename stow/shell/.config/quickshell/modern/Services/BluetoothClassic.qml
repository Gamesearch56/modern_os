pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// Pairs a device through one short bluetoothctl session.
// BlueZ needs a pairing agent; without one it rejects Pair() and keeps
// a pairing the device starts itself only as a temporary key, which is
// dropped at the next disconnect (buds lose the bond after the case).
// The session's NoInputNoOutput agent auto-accepts only pairings this
// side starts, and it exists only while the user is pairing, so a
// stranger's pairing request is still refused the rest of the time.
// Dual-mode buds also advertise on LE, and BlueZ pairs on whichever
// transport saw the device last, so a headset gets a classic-only scan
// first. BlueZ merges every client's search filter, so the shell's own
// dual-mode search is stopped before that scan.

Singleton {
    id: root

    property var _device: null
    property string _addr: ""
    property bool _waiting: false
    property bool _classic: false
    readonly property bool scanning: root._waiting || session.running

    function pair(device: var) {
        if (!device || root.scanning)
            return;
        root._device = device;
        root._addr = String(device.address || "");
        // A live link decides the transport on its own.
        root._classic = !device.connected && Bluetooth.isAudioDevice(device);
        root._waiting = true;
        stopWait.restart();
        Bluetooth.setDiscovering(false);
        if (!Bluetooth.discovering)
            quiet.restart();
    }

    function cancel() {
        root._device = null;
        root._waiting = false;
        quiet.stop();
        stopWait.stop();
        scanTime.stop();
        session.running = false;
    }

    function _start() {
        quiet.stop();
        stopWait.stop();
        if (!root._waiting)
            return;
        root._waiting = false;
        if (!root._device || !root._addr.length)
            return;
        session.running = true;
    }

    function _begin() {
        guard.restart();
        // A bluetoothctl session can leave the adapter non-pairable behind it.
        session.write("pairable on\n");
        if (root._classic) {
            session.write("scan bredr\n");
            scanTime.restart();
        } else {
            root._pairNow();
        }
    }

    function _pairNow() {
        if (!session.running)
            return;
        if (root._classic)
            session.write("scan off\n");
        session.write("pair " + root._addr + "\n");
    }

    function _read(raw: string) {
        const line = raw.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/[\x00-\x1f]/g, " ");
        if (line.indexOf("Pairing successful") !== -1) {
            session.write("trust " + root._addr + "\n");
        } else if (line.indexOf("trust succeeded") !== -1) {
            session.write("quit\n");
        } else if (line.indexOf("Failed to pair") !== -1) {
            Logger.warn("Bluetooth", "pairing failed: " + line.replace(/.*Failed to pair:?\s*/, "").trim());
            session.write("quit\n");
        }
    }

    Connections {
        target: Bluetooth
        enabled: root._waiting
        // A Start still in flight lands after the Stop; stop it again.
        function onDiscoveringChanged() {
            if (Bluetooth.discovering) {
                quiet.stop();
                Bluetooth.setDiscovering(false);
            } else {
                quiet.restart();
            }
        }
    }

    Timer {
        id: quiet
        interval: Math.max(Motion.bluetoothQuietMs, 1)
        onTriggered: root._start()
    }

    Timer {
        id: stopWait
        interval: Math.max(Motion.bluetoothStopWaitMs, 1)
        onTriggered: {
            Logger.warn("Bluetooth", "search did not stop before pairing; scanning anyway");
            root._start();
        }
    }

    Timer {
        id: scanTime
        interval: Math.max(Motion.bluetoothClassicScanMs, 1)
        onTriggered: root._pairNow()
    }

    Timer {
        id: guard
        interval: Math.max(Motion.bluetoothPairMs, 1)
        onTriggered: session.running = false
    }

    Process {
        id: session
        running: false
        stdinEnabled: true
        command: ["bluetoothctl", "--agent", "NoInputNoOutput"]
        stdout: SplitParser {
            onRead: (line) => root._read(line)
        }
        onStarted: root._begin()
        onExited: {
            guard.stop();
            scanTime.stop();
            root._device = null;
        }
    }
}
