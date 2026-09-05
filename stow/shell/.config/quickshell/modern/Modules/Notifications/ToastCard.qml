import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Overlay glass toast. Fields are bound by the Repeater (same pattern
// as the control-panel MListItem) — do not rely on injected modelData.
// Dismiss/hide by uid so Repeater copies of the JS item still resolve.
MouseArea {
    id: root

    property string summary: ""
    property string body: ""
    property string image: ""
    property string appIcon: ""
    property int expireTimeout: 0
    property var shownAt: 0
    property int uid: 0
    property var notification: null

    readonly property string _thumb: Notifications.displayImage(root.notification || root)

    readonly property string _iconName: Notifications.displayIcon(root.notification || root)

    readonly property url _iconSource: Notifications.displayIconSource(root.notification || root)

    readonly property int _timeout: root.expireTimeout
    property real remain: 1

    width: Tokens.spacing.xxl * 12
    implicitWidth: width
    implicitHeight: inner.implicitHeight + Tokens.spacing.md * 2
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    Accessible.role: Accessible.Button
    Accessible.name: root.summary
    Accessible.onPressAction: root._activate()
    onClicked: root._activate()

    function _remainNow(): real {
        if (root._timeout <= 0)
            return 0;
        const shown = Number(root.shownAt);
        if (!(shown > 0))
            return 1;
        return Math.max(0, Math.min(1, ((shown + root._timeout) - Date.now()) / root._timeout));
    }

    function _id() {
        return root.uid > 0 ? root.uid : root.notification;
    }

    function _close() {
        const id = root._id();
        Qt.callLater(() => Notifications.dismiss(id));
    }

    function _activate() {
        const id = root._id();
        const path = Notifications.attachmentPath(root.notification);
        Qt.callLater(() => {
            if (!Notifications.invokeDefault(id) && path.length)
                Apps.openPath(path);
            Notifications.dismiss(id);
        });
    }

    onShownAtChanged: root._startDrain()
    onExpireTimeoutChanged: root._startDrain()
    Component.onCompleted: root._startDrain()

    NumberAnimation {
        id: drain
        target: root
        property: "remain"
        to: 0
        easing.type: Easing.Linear
    }

    function _startDrain() {
        drain.stop();
        if (root._timeout <= 0) {
            root.remain = 0;
            return;
        }
        const left = root._remainNow();
        root.remain = left;
        drain.from = left;
        drain.duration = Math.max(1, Math.round(left * root._timeout));
        drain.start();
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
    }

    MLinearProgress {
        visible: root._timeout > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Tokens.spacing.xs
        value: root.remain
        enclosureRadius: Tokens.radius.medium
        enclosureHeight: root.height
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: "transparent"
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
    }

    RowLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.md
        spacing: Tokens.spacing.xl

        Rectangle {
            visible: root._thumb.length > 0 && toastThumb.status === Image.Ready
            Layout.preferredWidth: Tokens.icon.lg
            Layout.preferredHeight: Tokens.icon.lg
            Layout.alignment: Qt.AlignTop
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                id: toastThumb
                anchors.fill: parent
                source: root._thumb
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Tokens.icon.lg
                sourceSize.height: Tokens.icon.lg
            }
        }

        MIcon {
            visible: toastThumb.status !== Image.Ready
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Tokens.icon.md
            Layout.preferredHeight: Tokens.icon.md
            name: root._iconSource.toString().length > 0 ? "" : root._iconName
            source: root._iconSource
            size: Tokens.icon.md
            tint: root._iconSource.toString().length === 0
            color: Colors.color.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xxs

            MText {
                Layout.fillWidth: true
                value: root.summary
                styleName: "titleSmall"
            }

            MText {
                Layout.fillWidth: true
                visible: root.body.length > 0
                value: root.body
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }
        }

        Item {
            Layout.preferredWidth: Tokens.spacing.xl
            Layout.preferredHeight: Tokens.spacing.xl
        }
    }

    MIconButton {
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.spacing.xs
        close: true
        tabFocus: false
        iconName: "window-close"
        key: "bar.close"
        size: Tokens.spacing.xl
        iconSize: Tokens.icon.sm
        onClicked: root._close()
    }
}
