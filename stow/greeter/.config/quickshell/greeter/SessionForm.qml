import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property var users: null
    property string defaultUser: ""
    property bool autoFocus: false

    readonly property var _c: root.chrome
    readonly property bool _busy: root.auth ? root.auth.busy : false
    readonly property bool _launching: root.auth ? root.auth.launching : false
    readonly property string _fail: root.auth ? String(root.auth.failText || "") : ""
    readonly property bool _capsOn: password.capsOn
    readonly property string _error: {
        if (!root.auth || root._busy || root._launching || !root._fail.length)
            return "";
        return root._c ? root._c.t("session.loginFailed") : "";
    }

    implicitWidth: root._c ? root._c.formWidth : 352
    implicitHeight: col.implicitHeight

    function focusPassword() {
        if (!root._busy && !root._launching)
            password.forceActiveFocus();
    }

    function closeMenus() {
        identity.closeMenu();
    }

    function selectOpen(): bool {
        return identity.selectOpen();
    }

    function authenticate() {
        if (!root.auth)
            return;
        const local = password.text;
        const shared = String(root.auth.password || "");
        const p = local.length ? local : shared;
        root.auth.password = p;
        root.auth.login();
        password.text = "";
    }

    function _clearPassword() {
        password.text = "";
        if (root.auth)
            root.auth.password = "";
    }

    function _focusForm() {
        if (root._busy || root._launching || !root.autoFocus)
            return;
        password.forceActiveFocus();
        Qt.callLater(() => {
            if (!root._busy && !root._launching && root.autoFocus && !identity.selectOpen())
                password.forceActiveFocus();
        });
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root._c ? root._c.spaceLg : 16
        clip: false

        SessionIdentity {
            id: identity
            chrome: root._c
            Layout.fillWidth: true
            z: identity.menuOpen ? 40 : 0
            auth: root.auth
            users: root.users
            defaultUser: root.defaultUser
            autoFocus: root.autoFocus
            enabled: !root._busy && !root._launching
            onFocusPassword: root._focusForm()
        }

        SessionField {
            id: password
            chrome: root._c
            Layout.fillWidth: true
            placeholder: root._c ? root._c.t("session.password") : ""
            echoMode: TextInput.Password
            enabled: !root._busy && !root._launching
            tabFocus: root.autoFocus
            onTextEdited: {
                if (root.auth)
                    root.auth.password = text;
            }
            onAccepted: root.authenticate()
        }

        Text {
            visible: root._capsOn && !root._busy && !root._launching
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("bodySmall") : 12
            text: root._c ? root._c.t("session.capsLock") : ""
            Accessible.role: Accessible.Alert
            Accessible.name: text
        }

        Text {
            visible: root._error.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: root._c ? root._c.color.error : "#ffb4ab"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("bodySmall") : 12
            text: root._error
            Accessible.role: Accessible.Alert
            Accessible.name: text
        }

        Text {
            visible: root._busy || root._launching
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: root._c ? root._c.color.onSurfaceVariant : "#CAC4D0"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("bodySmall") : 12
            text: root._c ? root._c.t("session.signingIn") : ""
            Accessible.role: Accessible.Alert
            Accessible.name: text
        }

        SessionButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: root._c ? root._c.spaceXl : 24
            chrome: root._c
            label: root._c ? root._c.t("session.signIn") : ""
            enabled: !root._busy && !root._launching
                && root.auth && String(root.auth.username || "").length > 0
                && (password.text.length > 0
                    || String(root.auth.password || "").length > 0)
            busy: root._busy || root._launching
            tabFocus: root.autoFocus
            onClicked: root.authenticate()
        }
    }

    Connections {
        target: root.auth
        function onBusyChanged() {
            if (!root._busy && root.auth && root.auth.failText.length) {
                root._clearPassword();
                root.focusPassword();
            }
        }
        function onLaunchingChanged() {
            if (!root._launching && !root._busy)
                root._focusForm();
        }
        function onPasswordChanged() {
            const p = String(root.auth.password || "");
            if (password.text !== p)
                password.text = p;
        }
        function onUsernameChanged() {
            root._clearPassword();
            root._focusForm();
        }
        function onDefaultReadyChanged() {
            root._focusForm();
        }
    }

    Connections {
        target: root.users
        function onAccountsChanged() {
            root._focusForm();
        }
    }

    Timer {
        interval: 80
        running: root.visible && root.autoFocus
        repeat: false
        onTriggered: root._focusForm()
    }

    onDefaultUserChanged: root._focusForm()
    Component.onCompleted: root._focusForm()
}
