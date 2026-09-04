import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property var users: null
    property string defaultUser: ""
    property bool autoFocus: false
    property bool enabled: true

    readonly property var _c: root.chrome
    readonly property var _rows: {
        const raw = root.users ? (root.users.accounts || []) : [];
        const rem = String(root.defaultUser || "").trim();
        const n = raw.length;
        if (typeof n !== "number" || n <= 0)
            return [];
        if (!rem.length)
            return raw;
        const first = [];
        const rest = [];
        for (let i = 0; i < n; i++) {
            if (String(raw[i].value) === rem)
                first.push(raw[i]);
            else
                rest.push(raw[i]);
        }
        return first.concat(rest);
    }
    readonly property var _picked: {
        const u = String(root.auth ? root.auth.username : "");
        const rows = root._rows;
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i].value) === u)
                return rows[i];
        }
        return ({});
    }

    signal focusPassword()

    readonly property bool menuOpen: userSelect.menuOpen

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    z: userSelect.menuOpen ? 40 : 0

    function closeMenu() {
        userSelect.closeMenu();
    }

    function selectOpen(): bool {
        return userSelect.menuOpen;
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
        if (!String(root.defaultUser || "").trim() && root.auth && root.auth.defaultReady === false)
            return;
        root.auth.username = String(rows[0].value || "");
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root._c ? root._c.spaceMd : 12
        clip: false

        SessionAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: root._c ? root._c.spaceSm : 8
            chrome: root._c
            login: String(root._picked.value || "")
            home: String(root._picked.home || "")
            label: String(root._picked.titleValue || root._picked.value || "")
        }

        Text {
            visible: String(root._picked.titleValue || root._picked.value || "").length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: root._c ? root._c.spaceXl : 24
            text: String(root._picked.titleValue || root._picked.value || "")
            color: root._c ? root._c.color.onSurface : "#E6E0E9"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("titleMedium") : 16
            font.weight: root._c ? root._c.typeWeight("titleMedium") : 500
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        SessionSelect {
            id: userSelect
            chrome: root._c
            Layout.fillWidth: true
            Layout.topMargin: String(root._picked.titleValue || root._picked.value || "").length > 0
                ? 0
                : (root._c ? root._c.spaceXl : 24)
            model: root._rows
            value: root.auth ? root.auth.username : ""
            placeholder: root._c ? root._c.t("session.user") : ""
            enabled: root.enabled
            tabFocus: root.autoFocus && !String(root.auth ? root.auth.username : "").length
            onSelected: (val) => {
                if (root.auth)
                    root.auth.username = String(val || "");
                if (root.autoFocus)
                    root.focusPassword();
            }
        }
    }

    Connections {
        target: root.auth
        function onUsernameChanged() {
            root._pickUser();
        }
        function onDefaultReadyChanged() {
            root._pickUser();
        }
    }

    Connections {
        target: root.users
        function onAccountsChanged() {
            root._pickUser();
        }
    }

    onDefaultUserChanged: root._pickUser()
    Component.onCompleted: root._pickUser()
}
