// NetworkManager via Quickshell.Networking. WiFi list, wired state,
// connectivity. The network widget never calls nmcli.
pragma Singleton

import Quickshell
import Quickshell.Networking
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
}
