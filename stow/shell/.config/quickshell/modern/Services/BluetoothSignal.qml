pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"
import "signalLevel.js" as SignalLevel

// Bluetooth signal and range, from the RSSI BlueZ reports while a search
// runs. Quickshell's device has no RSSI, so this follows BlueZ's D-Bus
// signals (`gdbus monitor`) for exactly as long as a search lasts; BlueZ
// sends none outside one. A device heard in the last search is in range.
// The previous search's readings stay until the next one ends, so a list
// does not blank out while it is refreshed.

Singleton {
    id: root

    readonly property bool _active: Bluetooth.refreshing || Bluetooth.discovering
    // True once a search has finished, so "not found" means something.
    property bool searched: false
    property int rev: 0
    property var _heard: ({})
    property var _live: ({})
    property bool _dirty: false

    on_ActiveChanged: {
        if (root._active) {
            root._live = {};
            monitor.running = true;
            return;
        }
        monitor.running = false;
        const kept = {};
        for (const addr in root._live) {
            if (root._heard[addr] !== undefined)
                kept[addr] = root._heard[addr];
        }
        root._heard = kept;
        root.searched = true;
        root.rev += 1;
    }

    function _addr(device: var): string {
        return String(device?.address || "").toUpperCase();
    }

    // 0–4 bars, or -1 when the device was not heard in the last search.
    function level(device: var): int {
        void root.rev;
        return SignalLevel.bluetooth(root._heard[root._addr(device)]);
    }

    function inRange(device: var): bool {
        void root.rev;
        if (!device)
            return false;
        return !!device.connected || root._heard[root._addr(device)] !== undefined;
    }

    // Saved devices in range, then saved ones not heard, then the rest;
    // within each, the stronger signal first. 0 leaves the caller's order.
    function compare(a: var, b: var): int {
        const tier = d => Bluetooth.isRemembered(d) ? (root.inRange(d) ? 0 : 1) : 2;
        const t = tier(a) - tier(b);
        if (t !== 0)
            return t;
        return root.level(b) - root.level(a);
    }

    function _flush() {
        root._dirty = false;
        root.rev += 1;
    }

    function _read(line: string) {
        const m = /dev_([0-9A-F]{2}(?:_[0-9A-F]{2}){5})[\s\S]*?'RSSI': <(?:int16 )?(-?\d+)>/.exec(line);
        if (!m)
            return;
        const addr = m[1].replace(/_/g, ":");
        root._heard = Object.assign({}, root._heard, { [addr]: Number(m[2]) });
        root._live = Object.assign({}, root._live, { [addr]: true });
        if (!root._dirty) {
            root._dirty = true;
            Qt.callLater(root._flush);
        }
    }

    Process {
        id: monitor
        running: false
        command: ["gdbus", "monitor", "--system", "--dest", "org.bluez"]
        stdout: SplitParser {
            onRead: (line) => root._read(line)
        }
    }
}
