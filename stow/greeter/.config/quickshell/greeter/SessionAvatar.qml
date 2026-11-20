// Circular face for the selected login. Mirrors Widgets/MAvatar without
// Commons. Prefers the session snapshot so the greeter need not read $HOME.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var chrome: null
    property string login: ""
    property string home: ""
    property string label: ""

    readonly property var _c: root.chrome
    readonly property real _size: root._c ? root._c.avatarSize : 112
    readonly property string _letter: {
        const s = String(root.label || root.login || "").trim();
        if (!s.length)
            return "";
        return s.charAt(0).toUpperCase();
    }
    readonly property var _candidates: {
        const out = [];
        const login = String(root.login || "");
        if (login.length && login.indexOf("/") < 0 && login.indexOf("\\") < 0
                && login !== "." && login !== "..") {
            out.push("file:///var/lib/modern/session/faces/" + login);
            out.push("file:///var/lib/AccountsService/icons/" + login);
        }
        const home = String(root.home || "");
        if (home.indexOf("/") === 0) {
            out.push("file://" + home + "/.face");
            out.push("file://" + home + "/.face.icon");
        }
        return out;
    }

    property int _i: 0

    implicitWidth: root._size
    implicitHeight: root._size
    Accessible.ignored: true

    onLoginChanged: root._i = 0
    onHomeChanged: root._i = 0

    readonly property string _src: {
        const c = root._candidates;
        if (root._i >= 0 && root._i < c.length)
            return c[root._i];
        return "";
    }

    Item {
        id: disc
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: discMask
        }

        Rectangle {
            anchors.fill: parent
            color: root._c ? root._c.color.primaryContainer : "#4F378B"
        }

        Image {
            id: face
            anchors.fill: parent
            source: root._src
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            onStatusChanged: {
                if (status !== Image.Error)
                    return;
                if (root._i + 1 < root._candidates.length)
                    root._i += 1;
            }
            Accessible.ignored: true
        }

        Text {
            visible: !face.visible && root._letter.length > 0
            anchors.centerIn: parent
            text: root._letter
            color: root._c ? root._c.color.onPrimaryContainer : "#EADDFF"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: Math.round(root._size * 0.4)
            font.weight: 500
            Accessible.ignored: true
        }

        Item {
            visible: !face.visible && root._letter.length === 0
            anchors.centerIn: parent
            width: Math.round(root._size * 0.42)
            height: Math.round(root._size * 0.48)
            Accessible.ignored: true

            Rectangle {
                width: Math.round(parent.width * 0.42)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                color: root._c ? root._c.color.onPrimaryContainer : "#EADDFF"
            }

            Rectangle {
                width: parent.width
                height: Math.round(parent.height * 0.4)
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                color: root._c ? root._c.color.onPrimaryContainer : "#EADDFF"
            }
        }
    }

    Item {
        id: discMask
        visible: false
        anchors.fill: disc
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
        }
    }
}
