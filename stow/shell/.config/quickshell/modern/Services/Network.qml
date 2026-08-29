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
        void root.wifi;
        void root.wired;
        void root.connectivity;
        void Networking.devices;
        return root._wifiUp() || root._wiredUp() || root._linkUp();
    }
    readonly property string primaryName: {
        void root.wifi;
        void root.wired;
        void root.connectivity;
        void Networking.devices;
        if (root.wifi?.ssid)
            return root.wifi.ssid;
        if (root._wiredUp())
            return "ethernet";
        return "";
    }

    function _deviceUp(d: var): bool {
        if (!d)
            return false;
        if (d.active || d.connected || d.carrier || d.hasLink)
            return true;
        if (d.network && (d.network.active || d.network.connected))
            return true;
        return false;
    }

    function _wifiUp(): bool {
        const w = root.wifi;
        if (w && (w.active || w.connected) && w.ssid && w.ssid.length > 0)
            return true;
        const nets = w?.networks?.values ?? w?.networks ?? [];
        for (let i = 0; i < nets.length; i++) {
            const n = nets[i];
            if (n && (n.active || n.connected) && ((n.ssid && n.ssid.length > 0) || (n.name && String(n.name).length > 0)))
                return true;
        }
        return false;
    }

    function _wiredUp(): bool {
        const d = root.wired;
        if (root._deviceUp(d))
            return true;
        const list = d?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (root._deviceUp(list[i]))
                return true;
        }
        if (d && d.length) {
            for (let i = 0; i < d.length; i++) {
                if (root._deviceUp(d[i]))
                    return true;
            }
        }
        const devices = Networking.devices?.values ?? [];
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i];
            if (!dev)
                continue;
            if (dev.type === DeviceType.Wifi)
                continue;
            if (root._deviceUp(dev))
                return true;
        }
        return false;
    }

    function _linkUp(): bool {
        const c = root.connectivity;
        if (c === NetworkConnectivity.Full || c === NetworkConnectivity.Portal || c === NetworkConnectivity.Limited)
            return true;
        const s = String(c).toLowerCase();
        if (s.indexOf("full") !== -1 || s.indexOf("portal") !== -1 || s.indexOf("limited") !== -1)
            return true;
        const n = Number(c);
        return !isNaN(n) && n >= 2;
    }

    property bool watching: false
    property var bitrateSamples: []
    property real rxMbps: 0
    property real txMbps: 0
    property var _prevBytes: ({ rx: 0, tx: 0, at: 0 })
    property bool speedTesting: false
    property real speedMbps: 0
    readonly property bool wiredConnected: root._wiredUp()

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

    function needsPassword(network: var): bool {
        if (!network || network.active)
            return false;
        if (network.isSecure === true)
            return true;
        const s = String(network.security || network.flags || "").toLowerCase();
        if (s.length === 0)
            return false;
        return s.indexOf("open") === -1 && s.indexOf("none") === -1;
    }

    function speedTest() {
        if (root.speedTesting)
            return;
        root.speedTesting = true;
        root.speedMbps = 0;
        speedProc.running = true;
    }

    Process {
        id: speedProc
        command: ["curl", "-L", "--max-time", "8", "-o", "/dev/null", "-s", "-w", "%{speed_download}", "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const bps = Number((this.text || "").trim());
                if (!isNaN(bps) && bps > 0)
                    root.speedMbps = bps * 8 / 1000000;
                root.speedTesting = false;
            }
        }
        onExited: root.speedTesting = false
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
