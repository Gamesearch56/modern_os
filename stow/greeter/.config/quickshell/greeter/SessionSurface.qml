// Login layout for greetd. Hero clock, compact credentials on frost,
// power in the corner. Wallpaper stays while chrome fades into launch.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property var users: null
    property bool interactive: false
    property bool _entered: false

    readonly property bool _shown: root._entered && !(root.auth && root.auth.launching)
    readonly property var _c: root.chrome

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Component.onCompleted: root._entered = true

    SessionFrost {
        anchors.fill: parent
        chrome: root.chrome
    }

    MouseArea {
        anchors.fill: parent
        enabled: !power.menuOpen && root.interactive
        onPressed: {
            if (userSelectOpen())
                form.closeMenus();
            else
                form.focusPassword();
        }
    }

    Item {
        id: chrome
        anchors.fill: parent
        opacity: {
            if (!root._c)
                return root._shown ? 1 : 0;
            return root._c.overlayOpacity(root._shown);
        }
        scale: {
            if (!root._c)
                return 1;
            return root._c.overlayScale(root._shown);
        }
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: root._c ? root._c.overlaysFade : true
            NumberAnimation {
                duration: root._c ? root._c.extraLongMs : 600
                easing.bezierCurve: root._shown
                    ? (root._c ? root._c.easingDecel : [0.05, 0.7, 0.1, 1.0, 1.0, 1.0])
                    : (root._c ? root._c.easingAccel : [0.3, 0.0, 0.8, 0.15, 1.0, 1.0])
            }
        }
        Behavior on scale {
            enabled: root._c ? root._c.overlaysZoom : true
            NumberAnimation {
                duration: root._c ? root._c.extraLongMs : 600
                easing.bezierCurve: root._shown
                    ? (root._c ? root._c.easingDecel : [0.05, 0.7, 0.1, 1.0, 1.0, 1.0])
                    : (root._c ? root._c.easingAccel : [0.3, 0.0, 0.8, 0.15, 1.0, 1.0])
            }
        }

        SessionClock {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root._c ? root._c.spaceXxl * 2 : 64
            chrome: root._c
            date: clock.date
        }

        SessionForm {
            id: form
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root._c ? root._c.spaceXl : 24
            chrome: root._c
            auth: root.auth
            users: root.users
            defaultUser: root.auth ? root.auth.rememberedUser : ""
            autoFocus: root.interactive
        }

        MouseArea {
            anchors.fill: parent
            visible: power.menuOpen
            onClicked: power.close()
        }

        SessionPower {
            id: power
            chrome: root._c
            tabFocus: root.interactive
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: root._c ? root._c.spaceLg : 16
        }
    }

    function userSelectOpen() {
        return form.selectOpen();
    }
}
