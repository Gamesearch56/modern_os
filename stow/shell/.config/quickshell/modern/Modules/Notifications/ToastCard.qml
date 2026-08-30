import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Overlay glass toast. Fields are bound by the Repeater (same pattern
// as the control-panel MListItem) — do not rely on injected modelData.
Item {
    id: root

    property string summary: ""
    property string body: ""
    property string image: ""
    property string appIcon: ""
    property int expireTimeout: 0
    property var shownAt: 0
    property var notification: null

    readonly property string _thumb: {
        const img = root.image;
        if (!img.length)
            return "";
        const lower = img.toLowerCase();
        const shot = lower.indexOf("screenshot") !== -1
            || lower.indexOf("/pictures/") !== -1
            || lower.indexOf("/tmp/") !== -1;
        if (!shot && lower.indexOf(".png") === -1 && lower.indexOf(".jpg") === -1)
            return "";
        return img.indexOf("://") !== -1 ? img : ("file://" + img);
    }

    readonly property string _iconName: {
        const a = root.appIcon;
        if (!a.length || a.indexOf("/") !== -1 || a.indexOf(":") !== -1)
            return "dialog-information-symbolic";
        return a;
    }

    readonly property url _iconSource: {
        const a = root.appIcon;
        if (a.indexOf("/") === 0)
            return "file://" + a;
        if (a.indexOf("://") !== -1)
            return a;
        return "";
    }

    readonly property int _timeout: root.expireTimeout
    property real remain: root._timeout > 0 ? 1 : 0

    width: Tokens.spacing.xxl * 12
    implicitWidth: width
    implicitHeight: inner.implicitHeight + Tokens.spacing.md * 2
    Accessible.role: Accessible.Button
    Accessible.name: root.summary
    Accessible.onPressAction: root._activate()

    function _activate() {
        const path = Notifications.attachmentPath(root.notification);
        if (path.length)
            Apps.openInFileManager(path);
        Notifications.dismiss(root.notification);
    }

    Component.onCompleted: {
        if (root._timeout <= 0)
            return;
        const shown = Number(root.shownAt) || Date.now();
        const left = Math.max(0, (shown + root._timeout) - Date.now());
        root.remain = left / root._timeout;
        drain.duration = left;
        drain.start();
    }

    NumberAnimation {
        id: drain
        target: root
        property: "remain"
        to: 0
        easing.type: Easing.Linear
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: "transparent"
        border.color: Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root._activate()
    }

    RowLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.md
        spacing: Tokens.spacing.sm

        Rectangle {
            visible: root._thumb.length > 0
            Layout.preferredWidth: Tokens.icon.lg
            Layout.preferredHeight: Tokens.icon.lg
            Layout.alignment: Qt.AlignTop
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: root._thumb
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Tokens.icon.lg
                sourceSize.height: Tokens.icon.lg
            }
        }

        MIcon {
            visible: root._thumb.length === 0
            Layout.alignment: Qt.AlignTop
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

        MIconButton {
            z: 3
            Layout.alignment: Qt.AlignTop
            close: true
            iconName: "window-close"
            key: "bar.close"
            size: Tokens.spacing.xl
            iconSize: Tokens.icon.sm
            onClicked: Notifications.dismiss(root.notification)
        }
    }

    // Clip a matching rounded rect so the drain is the bottom stroke,
    // including the corner radius — not a square bar under the pill.
    Item {
        visible: root._timeout > 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * root.remain
        height: Tokens.stroke.focus
        clip: true

        Rectangle {
            width: root.width
            height: root.height
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            radius: Tokens.radius.medium
            color: Colors.color.primary
        }
    }
}
