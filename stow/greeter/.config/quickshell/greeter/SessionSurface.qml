// Duplicate of Modules/Session/SessionSurface.qml for the greetd
// package. Relative imports into the desktop shell do not survive
// stow (different target user / prefix), so the layout is copied
// rather than imported. Quickshell.Services.Greetd belongs in
// authenticate() once the gated greetd unit is enabled.
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
        scrim: "#000000"
    })

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
            font.pixelSize: 57
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root._date()
            color: root.color.onSurfaceVariant
            font.pixelSize: 16
        }

        TextInput {
            id: password
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            echoMode: TextInput.Password
            color: root.color.onSurface
            padding: 12
            onAccepted: root.authenticate(text)

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
            }
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
                font.pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.authenticate(password.text)
            }
        }
    }

    function authenticate(passwordText: string) {
        // Quickshell.Services.Greetd (`import Quickshell.Services.Greetd`)
        // is the real login path. Importing it in the desktop tree would
        // fail hosts that have not applied the gated greetd unit, so the
        // greeter instance owns that import when it lands.
        if (!passwordText || passwordText.length === 0)
            return;
    }

    function _t(key: string): string {
        if (key === "session.unlock")
            return "Unlock";
        if (key === "session.password")
            return "Password";
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
