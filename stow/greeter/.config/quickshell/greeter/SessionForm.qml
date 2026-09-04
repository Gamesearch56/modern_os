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
    readonly property var _rows: root.users ? (root.users.model || []) : []
    readonly property bool _busy: root.auth ? root.auth.busy : false
    readonly property bool _launching: root.auth ? root.auth.launching : false
    readonly property string _fail: root.auth ? String(root.auth.failText || "") : ""
    readonly property bool _capsOn: password.capsOn
    readonly property string _error: {
        if (!root.auth || root._busy || root._launching)
            return "";
        if (!root.auth.socketReady || root._fail === "unavailable"
            || root._fail.indexOf("Connection refused") >= 0)
            return root._c ? root._c.t("session.unavailable") : "";
        if (!root._fail.length)
            return "";
        if (root._fail === "failed")
            return root._c ? root._c.t("session.loginFailed") : "";
        return root._fail;
    }

    implicitWidth: root._c ? root._c.formWidth : 352
    implicitHeight: col.implicitHeight

    function focusPassword() {
        if (!root._busy && !root._launching)
            password.forceActiveFocus();
    }

    function closeMenus() {
        userSelect.closeMenu();
    }

    function selectOpen(): bool {
        return userSelect.menuOpen;
    }

    function authenticate() {
        if (root.auth)
            root.auth.login();
    }

    function _focusForm() {
        if (root._busy || root._launching || !root.autoFocus)
            return;
        password.forceActiveFocus();
    }

    function _pickUser() {
        if (!root.auth)
            return;
        const rows = root._rows;
        if (!rows.length)
            return;
        const current = String(root.auth.username || "").trim();
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === current)
                return;
        }
        const fallback = String(root.defaultUser || "").trim();
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === fallback) {
                root.auth.username = fallback;
                return;
            }
        }
        if (root.auth && root.auth.defaultReady === false)
            return;
        root.auth.username = String(rows[0].value || "");
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root._c ? root._c.spaceLg : 16

        SessionSelect {
            id: userSelect
            chrome: root._c
            Layout.fillWidth: true
            model: root._rows
            value: root.auth ? root.auth.username : ""
            placeholder: root._c ? root._c.t("session.user") : ""
            enabled: !root._busy && !root._launching
            tabFocus: root.autoFocus
            onSelected: (val) => {
                if (root.auth)
                    root.auth.username = String(val || "");
                if (root.autoFocus)
                    password.forceActiveFocus();
            }
        }

        SessionField {
            id: password
            chrome: root._c
            Layout.fillWidth: true
            placeholder: root._c ? root._c.t("session.password") : ""
            echoMode: TextInput.Password
            enabled: !root._busy && !root._launching
            tabFocus: root.autoFocus
            text: root.auth ? root.auth.password : ""
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
            font.family: root._c ? root._c.fontFamily : "Inter"
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
            font.family: root._c ? root._c.fontFamily : "Inter"
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
            font.family: root._c ? root._c.fontFamily : "Inter"
            font.pixelSize: root._c ? root._c.typePx("bodySmall") : 12
            text: root._c ? root._c.t("session.signingIn") : ""
            Accessible.role: Accessible.Alert
            Accessible.name: text
        }

        SessionButton {
            Layout.alignment: Qt.AlignHCenter
            chrome: root._c
            label: root._c ? root._c.t("session.signIn") : ""
            enabled: !root._busy && !root._launching
                && root.auth && String(root.auth.username || "").length > 0
                && String(root.auth.password || "").length > 0
            busy: root._busy || root._launching
            tabFocus: root.autoFocus
            onClicked: root.authenticate()
        }
    }

    Connections {
        target: root.auth
        function onBusyChanged() {
            if (!root._busy && root.auth && root.auth.failText.length)
                root.focusPassword();
        }
        function onUsernameChanged() {
            root._pickUser();
        }
        function onDefaultReadyChanged() {
            root._pickUser();
            root._focusForm();
        }
    }

    Connections {
        target: root.users
        function onModelChanged() {
            root._pickUser();
            root._focusForm();
        }
    }

    Timer {
        interval: 80
        running: root.visible && root.autoFocus
        repeat: false
        onTriggered: root._focusForm()
    }

    onDefaultUserChanged: {
        root._pickUser();
        root._focusForm();
    }

    Component.onCompleted: {
        root._pickUser();
        root._focusForm();
    }
}
