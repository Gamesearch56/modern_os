// Login layout for greetd. Not the lock screen: clock lives in the
// header, credentials sit on a card, power is a corner menu.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property bool interactive: false
    property string _defaultUser: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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
        chrome: root.chrome
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && !(power.item && power.item.menuOpen)
        onPressed: {
            if (form.item)
                form.item.focusPassword();
        }
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.chrome ? root.chrome.spaceXxl : 32
        spacing: root.chrome ? root.chrome.spaceXs : 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.chrome ? root.chrome.formatTime(clock.date) : ""
            color: root.chrome ? root.chrome.color.onSurface : "#E6E0E9"
            font.family: root.chrome ? root.chrome.fontFamily : "Inter"
            font.pixelSize: root.chrome ? root.chrome.typePx("headlineSmall") : 24
            font.weight: 500
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.chrome ? root.chrome.formatDate(clock.date) : ""
            color: root.chrome ? root.chrome.color.onSurfaceVariant : "#CAC4D0"
            font.family: root.chrome ? root.chrome.fontFamily : "Inter"
            font.pixelSize: root.chrome ? root.chrome.typePx("titleMedium") : 16
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }

    Component {
        id: formComp
        SessionForm {
            chrome: root.chrome
            auth: root.auth
            defaultUser: root._defaultUser
        }
    }

    Loader {
        id: form
        active: root.interactive
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.chrome ? root.chrome.spaceXl : 24
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
        sourceComponent: formComp
    }

    MouseArea {
        anchors.fill: parent
        visible: power.item ? power.item.menuOpen : false
        onClicked: {
            if (power.item)
                power.item.close();
        }
    }

    Component {
        id: powerComp
        SessionPower {
            chrome: root.chrome
        }
    }

    Loader {
        id: power
        active: root.interactive
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.chrome ? root.chrome.spaceLg : 16
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
        sourceComponent: powerComp
    }
}
