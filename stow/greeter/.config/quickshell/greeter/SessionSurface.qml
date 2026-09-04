// Duplicate of Modules/Session/SessionSurface.qml for the greetd
// package. Relative imports into the desktop shell do not survive
// stow (different target user / prefix), so the layout is copied
// rather than imported. GreetdAuth owns Quickshell.Services.Greetd.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string _defaultUser: ""

    readonly property bool _busy: auth.busy
    readonly property string _user: username.text.trim()

    SessionChrome {
        id: chrome
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    GreetdAuth {
        id: auth
    }

    FileView {
        path: "/var/lib/modern/session/default-user"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = String(text() || "").trim();
            if (t.length)
                root._defaultUser = t;
        }
    }

    SessionFrost {
        anchors.fill: parent
        chrome: chrome
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - chrome.spaceXxl * 2, chrome.formWidth)
        spacing: chrome.spaceXl

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: chrome.spaceXxl * 3
            implicitHeight: chrome.spaceXxl * 3
            radius: chrome.radiusFull
            color: chrome.color.surfaceContainerHighest
            Accessible.ignored: true

            Text {
                anchors.centerIn: parent
                text: root._user.length ? root._user.charAt(0).toUpperCase() : ""
                color: chrome.color.onSurface
                font.family: chrome.fontFamily
                font.pixelSize: chrome.typePx("headlineSmall")
                font.weight: 500
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: chrome.formatTime(clock.date)
            color: chrome.color.onSurface
            font.family: chrome.fontFamily
            font.pixelSize: chrome.typePx("displayLarge")
            font.weight: chrome.typeWeight("displayLarge")
            Accessible.role: Accessible.StaticText
            Accessible.name: chrome.formatTime(clock.date)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: chrome.formatDate(clock.date)
            color: chrome.color.onSurfaceVariant
            font.family: chrome.fontFamily
            font.pixelSize: chrome.typePx("titleMedium")
            font.weight: chrome.typeWeight("titleMedium")
            Accessible.role: Accessible.StaticText
            Accessible.name: chrome.formatDate(clock.date)
        }

        SessionField {
            id: username
            chrome: chrome
            Layout.fillWidth: true
            placeholder: chrome.t("session.user")
            enabled: !root._busy
            onAccepted: password.forceActiveFocus()
        }

        SessionField {
            id: password
            chrome: chrome
            Layout.fillWidth: true
            placeholder: chrome.t("session.password")
            echoMode: TextInput.Password
            enabled: !root._busy
            onAccepted: root.authenticate()
        }

        Text {
            visible: auth.failText.length > 0 && !root._busy
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: chrome.color.error
            font.family: chrome.fontFamily
            font.pixelSize: chrome.typePx("bodySmall")
            text: auth.failText.length ? auth.failText : chrome.t("session.authFailed")
            Accessible.role: Accessible.Alert
            Accessible.name: text
        }

        Text {
            visible: root._busy
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: chrome.color.onSurfaceVariant
            font.family: chrome.fontFamily
            font.pixelSize: chrome.typePx("bodySmall")
            text: chrome.t("session.signingIn")
            Accessible.role: Accessible.Alert
            Accessible.name: chrome.t("session.signingIn")
        }

        SessionButton {
            Layout.alignment: Qt.AlignHCenter
            chrome: chrome
            label: root._busy ? chrome.t("session.signingIn") : chrome.t("session.unlock")
            enabled: !root._busy && root._user.length > 0 && password.text.length > 0
            busy: root._busy
            onClicked: root.authenticate()
        }
    }

    Connections {
        target: auth
        function onBusyChanged() {
            if (!auth.busy && auth.failText.length) {
                password.forceActiveFocus();
                password.selectAll();
            }
        }
    }

    Component.onCompleted: root._focusForm()

    on_DefaultUserChanged: {
        if (username.text.length === 0)
            username.text = root._defaultUser;
        root._focusForm();
    }

    function authenticate() {
        auth.login(username.text, password.text);
    }

    function _focusForm() {
        if (root._busy)
            return;
        if (root._defaultUser.length)
            password.forceActiveFocus();
        else
            username.forceActiveFocus();
    }
}
