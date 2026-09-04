import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property string defaultUser: ""

    readonly property var _c: root.chrome
    readonly property bool _busy: root.auth ? root.auth.busy : false
    readonly property string _user: username.text.trim()
    readonly property string _error: {
        if (!root.auth || root._busy)
            return "";
        if (!root.auth.socketReady || root.auth.failText === "unavailable"
            || root.auth.failText.indexOf("Connection refused") >= 0)
            return root._c ? root._c.t("session.unavailable") : "";
        if (!root.auth.failText.length)
            return "";
        if (root.auth.failText === "failed")
            return root._c ? root._c.t("session.loginFailed") : "";
        return root.auth.failText;
    }

    implicitWidth: root._c ? root._c.formWidth + root._c.spaceXl * 2 : 416
    implicitHeight: col.implicitHeight + (root._c ? root._c.spaceXl * 2 : 48)

    function focusPassword() {
        if (!root._busy)
            password.forceActiveFocus();
    }

    function authenticate() {
        if (root.auth)
            root.auth.login(username.text, password.text);
    }

    function _focusForm() {
        if (root._busy)
            return;
        if (root.defaultUser.length)
            password.forceActiveFocus();
        else
            username.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        radius: root._c ? root._c.radiusMedium : 16
        color: root._c ? root._c.color.surfaceContainer : "#211F26"
        border.color: root._c ? root._c.color.outlineVariant : "#49454F"
        border.width: root._c ? root._c.strokeHairline : 1
        Accessible.ignored: true
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root._c ? root._c.spaceXl : 24
        spacing: root._c ? root._c.spaceLg : 16

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root._c ? root._c.t("session.welcome") : ""
            color: root._c ? root._c.color.onSurface : "#E6E0E9"
            font.family: root._c ? root._c.fontFamily : "Inter"
            font.pixelSize: root._c ? root._c.typePx("headlineSmall") : 24
            font.weight: root._c ? root._c.typeWeight("headlineSmall") : 500
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root._c ? root._c.spaceXxl * 2 + root._c.spaceLg : 80
            implicitHeight: implicitWidth
            radius: root._c ? root._c.radiusFull : 9999
            color: root._c ? root._c.color.primaryContainer : "#4F378B"
            Accessible.ignored: true

            Text {
                anchors.centerIn: parent
                text: root._user.length ? root._user.charAt(0).toUpperCase() : ""
                color: root._c ? root._c.color.onPrimaryContainer : "#EADDFF"
                font.family: root._c ? root._c.fontFamily : "Inter"
                font.pixelSize: root._c ? root._c.typePx("headlineSmall") : 24
                font.weight: 500
            }
        }

        SessionField {
            id: username
            chrome: root._c
            Layout.fillWidth: true
            placeholder: root._c ? root._c.t("session.user") : ""
            enabled: !root._busy
            onAccepted: password.forceActiveFocus()
        }

        SessionField {
            id: password
            chrome: root._c
            Layout.fillWidth: true
            placeholder: root._c ? root._c.t("session.password") : ""
            echoMode: TextInput.Password
            enabled: !root._busy
            onAccepted: root.authenticate()
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
            visible: root._busy
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
            label: root._busy
                ? (root._c ? root._c.t("session.signingIn") : "")
                : (root._c ? root._c.t("session.signIn") : "")
            enabled: !root._busy && root._user.length > 0 && password.text.length > 0
            busy: root._busy
            onClicked: root.authenticate()
        }
    }

    Connections {
        target: root.auth
        function onBusyChanged() {
            if (!root._busy && root.auth && root.auth.failText.length)
                root.focusPassword();
        }
    }

    Timer {
        interval: 80
        running: root.visible
        repeat: false
        onTriggered: root._focusForm()
    }

    onDefaultUserChanged: {
        if (username.text.length === 0)
            username.text = root.defaultUser;
        root._focusForm();
    }

    Component.onCompleted: {
        if (root.defaultUser.length && username.text.length === 0)
            username.text = root.defaultUser;
        root._focusForm();
    }
}
