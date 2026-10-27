import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

Item {
    id: root

    property var pendingNet: null
    property bool forcePassword: false
    property bool joinError: false
    readonly property bool passwordOpen: root.pendingNet !== null
    readonly property bool _online: !!(root.pendingNet && root.pendingNet.connected)
    readonly property bool _known: !!(root.pendingNet && root.pendingNet.known)
    readonly property bool _locked: Network.isLocked(root.pendingNet)
    readonly property bool _askSecret: !root._online && ((!root._known && root._locked) || root.forcePassword)
    readonly property bool _secretRequired: root._askSecret && (!root._known || root.forcePassword)

    implicitHeight: col.implicitHeight

    onPendingNetChanged: {
        root.forcePassword = false;
        root.joinError = false;
        if (pwd)
            pwd.text = "";
    }

    function _confirm() {
        const net = root.pendingNet;
        if (!net || Network.joining)
            return;
        root.joinError = false;
        if (root._online) {
            Network.disconnect(net);
            return;
        }
        const secret = root._askSecret && pwd ? pwd.text : "";
        if (root._secretRequired && secret.length === 0)
            return;
        Network.connect(net, secret);
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.lg

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.md
                MText {
                    key: "settings.fields.wifi"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MSwitch {
                    enabled: Network.wifiHardwareEnabled
                    checked: Network.wifiEnabled
                    onToggled: (v) => Network.setWifiEnabled(v)
                }
            }
            MHint {
                key: Network.wifiHardwareEnabled ? "settings.hints.wifi" : "settings.hints.wifiHardware"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MIcon {
                name: "network-wired"
                size: Tokens.icon.md
            }
            ColumnLayout {
                spacing: Tokens.spacing.xxs
                Layout.fillWidth: true
                MText {
                    key: "settings.fields.ethernet"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MText {
                    visible: Network.wiredAddress.length > 0
                    value: Network.wiredAddress
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
            MText {
                key: Network.wiredConnected ? "settings.network.ethernetOn" : "settings.network.ethernetOff"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
            }
        }

        WifiList {
            Layout.fillWidth: true
            onNetworkClicked: (n) => root.pendingNet = n
        }

        SpeedPanel {
            Layout.fillWidth: true
        }
    }

    Connections {
        target: Network
        function onJoinFinished(op, ssid, ok) {
            if (!root.pendingNet || Network.ssidOf(root.pendingNet) !== ssid)
                return;
            if (ok) {
                root.pendingNet = null;
                return;
            }
            if (op === "connect") {
                root.forcePassword = root._locked;
                root.joinError = true;
                if (pwd)
                    pwd.text = "";
            }
        }
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pendingNet !== null
        titleValue: root.pendingNet ? (root.pendingNet.ssid || root.pendingNet.name || "") : ""
        bodyKey: root._online ? "settings.network.disconnectBody" : "settings.network.connectBody"
        confirmKey: root._online ? "settings.disconnect" : "settings.connectWifi"
        cancelKey: "powerMenu.cancel"
        destructiveKey: (root._online || root._known) ? "settings.network.forget" : ""
        confirmEnabled: !Network.joining && (!root._secretRequired || (pwd.text && pwd.text.length > 0))
        onConfirmed: root._confirm()
        onCancelled: root.pendingNet = null
        onDestructiveClicked: {
            if (root.pendingNet)
                Network.forget(root.pendingNet);
        }

        Item {
            visible: Network.joining
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Tokens.icon.lg : 0
            MIcon {
                anchors.centerIn: parent
                name: "view-refresh"
                size: Tokens.icon.md
                color: Colors.color.onSurfaceVariant
                RotationAnimation on rotation {
                    running: Network.joining
                    from: 0
                    to: 360
                    duration: Motion.extraLongMs
                    loops: Animation.Infinite
                }
            }
        }
        MText {
            visible: root.joinError && !Network.joining
            key: "settings.network.connectFailed"
            styleName: "bodyMedium"
            color: Colors.color.error
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }
        MTextField {
            id: pwd
            visible: root._askSecret
            enabled: !Network.joining
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
            echoMode: TextInput.Password
            placeholderKey: "settings.fields.wifiPassword"
            onAccepted: root._confirm()
        }
    }
}
