// NetworkManager via Quickshell.Networking. Wi-Fi list, wired state,
// connectivity. Rescan is `nmcli --rescan yes`; the widget never runs it.
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
        return root._wiredDevice();
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
    readonly property var _rawNets: {
        const w = root.wifi;
        if (!w)
            return root._none;
        const nets = w.networks;
        void nets;
        if (nets && nets.values)
            return nets.values;
        return nets ?? root._none;
    }
    readonly property string _netSig: {
        const raw = root._rawNets;
        let s = "";
        for (let i = 0; i < raw.length; i++) {
            const n = raw[i];
            void n?.name;
            void n?.ssid;
            void n?.connected;
            void n?.known;
            void n?.nmSettings;
            void n?.signalStrength;
            s += root._wifiKey(n) + ":" + (n && n.connected ? "1" : "0") + (n && (n.known || (n.nmSettings && n.nmSettings.length)) ? "k" : "") + ":" + (Number(n?.signalStrength) || 0) + ",";
        }
        return s;
    }
    readonly property var networks: {
        void root._wifiSeq;
        void root._netSig;
        return root._sortedWifi(root._rawNets);
    }

    readonly property var _none: []
    property var _wifiSeen: ({})
    property int _wifiSeq: 0
    property string _resumeSsid: ""
    readonly property bool scanning: scanProc.running || join.waking
    readonly property bool joining: join.running
    readonly property string linkKind: root._wifiUp() ? "wifi" : (root._wiredUp() ? "ethernet" : "offline")
    signal joinFinished(string op, string ssid, bool ok)
    readonly property bool speedTesting: speed.testing
    readonly property bool speedDone: speed.done
    readonly property bool speedFailed: speed.failed
    readonly property real speedMbps: speed.mbps
    readonly property real speedBytes: speed.bytes
    readonly property real speedSeconds: speed.seconds
    readonly property real speedDnsMs: speed.dnsMs
    readonly property real speedConnectMs: speed.connectMs
    readonly property int speedHttp: speed.http

    on_NetSigChanged: root._stampWifi()
    onWifiChanged: root._syncScan()
    onWifiEnabledChanged: {
        root._syncScan();
        if (!root.wifiEnabled)
            scanProc.running = false;
    }
    Component.onCompleted: root._syncScan()

    function _wifiKey(n: var): string {
        return String(n?.name || n?.ssid || "").trim();
    }

    function _stampWifi() {
        const raw = root._rawNets;
        const present = {};
        const next = Object.assign({}, root._wifiSeen);
        let seq = root._wifiSeq;
        let changed = false;
        for (let i = 0; i < raw.length; i++) {
            const key = root._wifiKey(raw[i]);
            if (!key.length)
                continue;
            present[key] = true;
            if (next[key] === undefined) {
                seq += 1;
                next[key] = seq;
                changed = true;
            }
        }
        for (const k in next) {
            if (raw.length > 0 && !present[k]) {
                delete next[k];
                changed = true;
            }
        }
        if (!changed)
            return;
        root._wifiSeen = next;
        root._wifiSeq = seq;
    }

    function _sortedWifi(raw: var): var {
        const list = [];
        for (let i = 0; i < raw.length; i++)
            list.push(raw[i]);
        list.sort((a, b) => {
            const ar = a?.connected ? 0 : (a && (a.known || (a.nmSettings && a.nmSettings.length)) ? 1 : 2);
            const br = b?.connected ? 0 : (b && (b.known || (b.nmSettings && b.nmSettings.length)) ? 1 : 2);
            if (ar !== br)
                return ar - br;
            const ds = (Number(b?.signalStrength) || 0) - (Number(a?.signalStrength) || 0);
            if (ds !== 0)
                return ds;
            const an = root._wifiKey(a);
            const bn = root._wifiKey(b);
            return an < bn ? -1 : (an > bn ? 1 : 0);
        });
        return list;
    }

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

    function _wiredDevice(): var {
        const list = root._list(Networking.devices);
        const virtualIface = /^(lo|docker|veth|virbr|vnet|br-|tun|tap|wg|zt|tailscale|nm-)/;
        let fallback = null;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            if (!d || d.type !== DeviceType.Wired || virtualIface.test(String(d.name || "")))
                continue;
            if (d.connected && d.hasLink !== false)
                return d;
            if (!fallback)
                fallback = d;
        }
        return fallback;
    }

    function _wiredUp(): bool {
        const d = root.wired;
        return !!(d && d.connected && d.hasLink !== false);
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
        if (!on)
            root._resumeSsid = root.ssid;
        Networking.wifiEnabled = on;
        if (!on) {
            scanProc.running = false;
            return;
        }
        root._syncScan();
        join.wake(root._resumeSsid);
    }

    function scan() {
        if (!root.wifiEnabled || scanProc.running)
            return;
        const secs = String(Math.max(1, Math.round(Motion.wifiScanMs / 1000)));
        scanProc.command = ["/usr/bin/nmcli", "-w", secs, "-t", "device", "wifi", "list", "--rescan", "yes"];
        scanProc.running = false;
        Qt.callLater(() => {
            if (root.wifiEnabled)
                scanProc.running = true;
        });
    }

    function ssidOf(network: var): string {
        return root._wifiKey(network);
    }

    function isLocked(network: var): bool {
        if (!network)
            return false;
        const sec = network.security;
        return sec !== undefined && sec !== null && sec !== WifiSecurityType.Open && sec !== WifiSecurityType.Owe;
    }

    function connect(network: var, password: string) {
        join.start("connect", root.ssidOf(network), password || "");
    }

    function disconnect(network: var) {
        const ssid = network ? root.ssidOf(network) : root.ssid;
        join.start("disconnect", ssid, "");
    }

    function forget(network: var) {
        join.start("forget", root.ssidOf(network), "");
    }

    function needsPassword(network: var): bool {
        return !!(network && !network.connected && !network.known && root.isLocked(network));
    }

    function speedTest() {
        speed.start();
    }

    NetworkJoin {
        id: join
        onFinished: (op, ssid, ok) => root.joinFinished(op, ssid, ok)
    }

    NetworkSpeed {
        id: speed
    }

    Process {
        id: scanProc
        running: false
        onExited: root._syncScan()
    }
}
