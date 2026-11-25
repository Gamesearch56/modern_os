// Login layout for greetd. Hero clock, compact credentials on frost,
// power in the corner. Wallpaper stays until greetd replaces this seat.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var chrome: null
    property var auth: null
    property var users: null
    property bool interactive: false
    property bool autoFocus: false
    property bool _entered: true
    property bool _animate: false

    readonly property bool _shown: root._entered
    readonly property bool _launching: !!(root.auth && root.auth.launching)
    readonly property var _c: root.chrome

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Component.onCompleted: {
        root._entered = true;
        Qt.callLater(() => {
            root._animate = true;
        });
    }

    SessionFrost {
        anchors.fill: parent
        chrome: root.chrome
        username: root.auth ? root.auth.username : ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: !power.menuOpen && root.interactive && !root._launching
        onPressed: {
            if (!form.item)
                return;
            if (form.item.selectOpen())
                form.item.closeMenus();
            else
                form.item.focusPassword();
        }
    }

    // Not id chrome: that name is the SessionChrome property on this
    // root, and a child id would steal t()/formatTime from every label.
    Item {
        id: overlay
        visible: !root._launching
        anchors.fill: parent
        opacity: {
            const c = root._c;
            if (!c || !c.overlayOpacity)
                return root._shown ? 1 : 0;
            return c.overlayOpacity(root._shown);
        }
        scale: {
            const c = root._c;
            if (!c || !c.overlayScale)
                return 1;
            return c.overlayScale(root._shown);
        }
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: root._animate && !!(root._c && root._c.overlaysFade)
            NumberAnimation {
                duration: root._c ? root._c.extraLongMs : 600
                easing.bezierCurve: root._shown
                    ? (root._c ? root._c.easingDecel : [0.05, 0.7, 0.1, 1.0, 1.0, 1.0])
                    : (root._c ? root._c.easingAccel : [0.3, 0.0, 0.8, 0.15, 1.0, 1.0])
            }
        }
        Behavior on scale {
            enabled: root._animate && !!(root._c && root._c.overlaysZoom)
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

        Loader {
            id: form
            active: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root._c ? root._c.spaceXl : 24
            sourceComponent: SessionForm {
                chrome: root._c
                auth: root.auth
                users: root.users
                defaultUser: root.auth ? root.auth.rememberedUser : ""
                autoFocus: root.autoFocus
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: power.menuOpen
            onClicked: power.close()
        }

        SessionPower {
            id: power
            chrome: root._c
            tabFocus: root.autoFocus
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: root._c ? root._c.spaceLg : 16
        }
    }

    Column {
        visible: root._launching
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root._c ? root._c.spaceXxl * 3 : 96
        spacing: root._c ? root._c.spaceMd : 12
        width: root._c ? root._c.formWidth : 352

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: root._c ? root._c.color.onSurface : "#E6E0E9"
            font.family: root._c ? root._c.fontFamily : "sans-serif"
            font.pixelSize: root._c ? root._c.typePx("bodySmall") : 12
            text: root._c ? root._c.t("session.signingIn") : ""
        }

        Item {
            id: track
            width: parent.width
            height: root._c ? root._c.spaceSm : 8

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root._c ? root._c.color.primary : "#D0BCFF"
                opacity: 0.24
            }

            Rectangle {
                id: thumb
                width: parent.width * 0.35
                height: parent.height
                radius: height / 2
                color: root._c ? root._c.color.primary : "#D0BCFF"

                SequentialAnimation on x {
                    running: root._launching && (!root._c || root._c.motionScale !== 0)
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0
                        to: track.width - thumb.width
                        duration: root._c ? root._c.extraLongMs : 600
                        easing.bezierCurve: root._c ? root._c.easingDecel : [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
                    }
                    NumberAnimation {
                        from: track.width - thumb.width
                        to: 0
                        duration: root._c ? root._c.extraLongMs : 600
                        easing.bezierCurve: root._c ? root._c.easingAccel : [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
                    }
                }
            }
        }
    }

    function userSelectOpen() {
        return !!(form.item && form.item.selectOpen());
    }
}
