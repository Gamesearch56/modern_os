// NetworkManager via Quickshell.Networking. WiFi list, wired state,
// connectivity. The network widget never calls nmcli.
pragma Singleton

import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var wifi: Network.wifi
    readonly property var wired: Network.wired
    readonly property int connectivity: Network.connectivity
    readonly property bool wifiEnabled: Network.wifiEnabled ?? (root.wifi?.enabled ?? false)
    readonly property bool connected: {
        const w = root.wifi;
        if (w && w.active && w.ssid && w.ssid.length > 0)
            return true;
        const d = root.wired;
        if (d && d.connected)
            return true;
        return false;
    }
    readonly property string primaryName: {
        if (root.wifi?.ssid)
            return root.wifi.ssid;
        if (root.wired?.connected)
            return "ethernet";
        return "";
    }

    property bool watching: false
    property var bitrateSamples: []
    property real rxMbps: 0
    property real txMbps: 0
    property var _prevBytes: ({ rx: 0, tx: 0, at: 0 })

    readonly property var networks: {
        const w = root.wifi;
        if (!w)
            return [];
        if (w.networks?.values)
            return w.networks.values;
        return w.networks ?? [];
    }

    function setWifiEnabled(on: bool) {
        Network.wifiEnabled = on;
    }

    function connect(network: var, password: string) {
        try {
            if (!network)
                return;
            if (password && password.length > 0)
                network.connect(password);
            else
                network.connect();
        } catch (e) {
            Logger.error("Network", String(e));
        }
    }

    function disconnect() {
        if (root.wifi?.disconnect)
            root.wifi.disconnect();
    }

    Process {
        id: bytesProc
        command: ["sh", "-c", "awk 'NR>2{rx+=$2;tx+=$10} END{print rx,tx}' /proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._sample(this.text)
        }
    }

    Timer {
        interval: 1000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: bytesProc.running = true
    }

    function _sample(text: string) {
        const parts = (text || "").trim().split(/\s+/);
        const rx = Number(parts[0]);
        const tx = Number(parts[1]);
        const now = Date.now();
        const prev = root._prevBytes;
        if (prev.at > 0 && now > prev.at) {
            const dt = (now - prev.at) / 1000;
            root.rxMbps = Math.max(0, (rx - prev.rx) * 8 / dt / 1000000);
            root.txMbps = Math.max(0, (tx - prev.tx) * 8 / dt / 1000000);
            const next = (root.bitrateSamples || []).slice();
            next.push(root.rxMbps + root.txMbps);
            if (next.length > 24)
                next.shift();
            root.bitrateSamples = next;
        }
        root._prevBytes = { rx: rx, tx: tx, at: now };
    }
}
