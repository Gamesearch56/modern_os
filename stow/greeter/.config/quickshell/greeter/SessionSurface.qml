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

    property string mode: "greeter"
    property var color: root._fallback
    property string wallpaperSource: "file:///var/lib/modern/session/wallpaper.jpg"

    readonly property var _fallback: ({
        surface: "#141218",
        onSurface: "#E6E0E9",
        onSurfaceVariant: "#CAC4D0",
        primary: "#D0BCFF",
        onPrimary: "#381E72",
        surfaceContainerHighest: "#36343B",
        outline: "#938F99",
        scrim: "#000000",
        error: "#ffb4ab"
    })

    property var chrome: ({ strings: { unlock: "Unlock", password: "Password" }, typography: { ui: "Inter", scale: 1 } })

    readonly property string _font: String(root.chrome?.typography?.ui || "Inter")
    readonly property real _typeScale: {
        const s = Number(root.chrome?.typography?.scale);
        return (s > 0) ? s : 1;
    }

    FileView {
        path: "/var/lib/modern/session/chrome.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data)
                    root.chrome = data;
            } catch (e) {
                /* keep fallback */
            }
        }
    }

    FileView {
        path: "/var/lib/modern/session/tokens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.color)
                    root.color = data.color;
            } catch (e) {
                root.color = root._fallback;
            }
        }
        onLoadFailed: root.color = root._fallback
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: root.color.surface
    }

    Image {
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Error && root.wallpaperSource.indexOf("default.jpg") < 0)
                root.wallpaperSource = "file://" + Quickshell.env("HOME") + "/.config/modern/wallpapers/default.jpg";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.color.scrim
        opacity: 0.48
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 384)
        spacing: 32

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._time()
            color: root.color.onSurface
            font.family: root._font
            font.pixelSize: Math.round(57 * root._typeScale)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._date()
            color: root.color.onSurfaceVariant
            font.family: root._font
            font.pixelSize: Math.round(16 * root._typeScale)
        }

        TextInput {
            id: username
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: root.color.onSurface
            font.family: root._font
            font.pixelSize: Math.round(16 * root._typeScale)
            padding: 12
            text: root._defaultUser
            onAccepted: password.forceActiveFocus()

            Rectangle {
                anchors.fill: parent
                z: -1
                radius: 8
                color: root.color.surfaceContainerHighest
                border.color: username.activeFocus ? root.color.primary : root.color.outline
            }

            Text {
                visible: username.text.length === 0
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: root._t("session.user")
                color: root.color.onSurfaceVariant
                font.family: root._font
                font.pixelSize: Math.round(16 * root._typeScale)
            }
        }

        TextInput {
            id: password
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            echoMode: TextInput.Password
            color: root.color.onSurface
            font.family: root._font
            font.pixelSize: Math.round(16 * root._typeScale)
            padding: 12
            onAccepted: root.authenticate(username.text, text)

            Rectangle {
                anchors.fill: parent
                z: -1
                radius: 8
                color: root.color.surfaceContainerHighest
                border.color: password.activeFocus ? root.color.primary : root.color.outline
            }

            Text {
                visible: password.text.length === 0
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: root._t("session.password")
                color: root.color.onSurfaceVariant
                font.family: root._font
                font.pixelSize: Math.round(16 * root._typeScale)
            }
        }

        Text {
            visible: auth.failText.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.color.error
            font.family: root._font
            font.pixelSize: Math.round(12 * root._typeScale)
            text: auth.failText
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: unlockLabel.implicitWidth + 32
            implicitHeight: 36
            radius: 9999
            color: root.color.primary

            Text {
                id: unlockLabel
                anchors.centerIn: parent
                text: root._t("session.unlock")
                color: root.color.onPrimary
                font.family: root._font
                font.pixelSize: Math.round(14 * root._typeScale)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.authenticate(username.text, password.text)
            }
        }
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

    property string _defaultUser: ""

    function authenticate(userText: string, passwordText: string) {
        auth.login(userText, passwordText);
    }

    function _t(key: string): string {
        const s = root.chrome?.strings || ({});
        if (key === "session.unlock")
            return s.unlock || "Unlock";
        if (key === "session.password")
            return s.password || "Password";
        if (key === "session.user")
            return s.user || "User";
        return key;
    }

    function _pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function _time(): string {
        const d = clock.date;
        if (!d)
            return "";
        return root._pad(d.getHours()) + ":" + root._pad(d.getMinutes());
    }

    function _date(): string {
        const d = clock.date;
        if (!d)
            return "";
        return root._pad(d.getDate()) + "." + root._pad(d.getMonth() + 1) + "." + d.getFullYear();
    }
}
