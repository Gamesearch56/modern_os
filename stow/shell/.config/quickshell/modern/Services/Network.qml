// NetworkManager via Quickshell.Networking. Wi-Fi list, wired state,
// connectivity. The network widget never calls nmcli.
pragma Singleton

import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var wifi: {
        void Networking.devices;
        return root._deviceOfType(DeviceType.Wifi);
    }
    readonly property var wired: {
        void Networking.devices;
        return root._deviceOfType(DeviceType.Wired);
    }
    readonly property int connectivity: Networking.connectivity
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wiredConnected: root._wiredUp()
    readonly property string wiredAddress: root.wired?.address ?? ""
    readonly property string ssid: {
        const list = root.networks;
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (!n)
                continue;
            void n.connected;
            void n.name;
            if (n.connected)
                return String(n.name || "");
        }
        return "";
    }
    readonly property bool connected: {
        void root.ssid;
        void root.wifi;
        void root.wired;
        void root.connectivity;
        return root._wifiUp() || root.wiredConnected || root._linkUp();
    }
    readonly property var networks: {
        const w = root.wifi;
        if (!w)
            return [];
        const nets = w.networks;
        void nets;
        if (nets && nets.values)
            return nets.values;
        return nets ?? [];
    }

    property bool speedTesting: false
    property bool speedDone: false
    property real speedMbps: 0
    property real speedBytes: 0
    property real speedSeconds: 0
    property real speedDnsMs: 0
    property real speedConnectMs: 0
    property int speedHttp: 0

    onWifiChanged: root._syncScan()
    onWifiEnabledChanged: root._syncScan()
    Component.onCompleted: root._syncScan()

    function _list(model: var): var {
        if (!model)
            return [];
        if (model.values)
            return model.values;
        return model;
    }

    function _deviceOfType(t: var): var {
        const list = root._list(Networking.devices);
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].type === t)
                return list[i];
        }
        return null;
    }

    function _wifiUp(): bool {
        const w = root.wifi;
        if (w && w.connected && root.ssid.length > 0)
            return true;
        const list = root.networks;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected)
                return true;
        }
        return false;
    }

    function _wiredUp(): bool {
        const d = root.wired;
        if (!d)
            return false;
        return !!(d.connected || d.hasLink);
    }

    function _linkUp(): bool {
        const c = root.connectivity;
        return c === NetworkConnectivity.Full || c === NetworkConnectivity.Portal || c === NetworkConnectivity.Limited;
    }

    function _syncScan() {
        const w = root.wifi;
        if (!w || w.scannerEnabled === undefined)
            return;
        w.scannerEnabled = root.wifiEnabled;
    }

    function setWifiEnabled(on: bool) {
        Networking.wifiEnabled = on;
        if (on)
            root._syncScan();
    }

    function connect(network: var, password: string) {
        try {
            if (!network)
                return;
            if (password && password.length > 0 && network.connectWithPsk)
                network.connectWithPsk(password);
            else if (network.connect)
                network.connect();
        } catch (e) {
            Logger.error("Network", String(e));
        }
    }

    function disconnect() {
        if (root.wifi && root.wifi.disconnect)
            root.wifi.disconnect();
    }

    function needsPassword(network: var): bool {
        if (!network || network.connected || network.known)
            return false;
        const sec = network.security;
        if (sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe)
            return false;
        return true;
    }

    function speedTest() {
        if (root.speedTesting)
            return;
        root.speedTesting = true;
        root.speedDone = false;
        root.speedMbps = 0;
        root.speedBytes = 0;
        root.speedSeconds = 0;
        root.speedDnsMs = 0;
        root.speedConnectMs = 0;
        root.speedHttp = 0;
        speedProc.running = true;
    }

    function _parseSpeed(text: string) {
        try {
            const obj = JSON.parse((text || "").trim());
            const bps = Number(obj.speed);
            if (!isNaN(bps) && bps > 0)
                root.speedMbps = bps * 8 / 1000000;
            root.speedBytes = Number(obj.bytes) || 0;
            root.speedSeconds = Number(obj.time) || 0;
            root.speedDnsMs = Math.round((Number(obj.dns) || 0) * 1000);
            root.speedConnectMs = Math.round((Number(obj.connect) || 0) * 1000);
            root.speedHttp = Number(obj.code) || 0;
            root.speedDone = true;
        } catch (e) {
            Logger.error("Network", String(e));
        }
        root.speedTesting = false;
    }

    Process {
        id: speedProc
        command: ["curl", "-L", "--max-time", "8", "-o", "/dev/null", "-s", "-w", "{\"speed\":%{speed_download},\"bytes\":%{size_download},\"time\":%{time_total},\"dns\":%{time_namelookup},\"connect\":%{time_connect},\"code\":\"%{http_code}\"}", "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseSpeed(this.text)
        }
        onExited: {
            if (root.speedTesting)
                root.speedTesting = false;
        }
    }
}
