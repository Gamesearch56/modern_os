// One row in a list. `variant` row uses tonal selected; nav uses a
// filled primary pill so Settings sidebar matches Material You.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
    property string iconSource: ""
    property string imageSource: ""
    property real imageSize: Tokens.icon.lg
    property bool tintIcon: true
    property string titleKey: ""
    property var titleParams: ({})
    property string titleValue: ""
    property string subtitleKey: ""
    property var subtitleParams: ({})
    property string subtitleValue: ""
    property bool selected: false
    property bool enabled: true
    property string variant: "row"
    property bool destructive: false
    property bool hoverHighlight: true
    property string badgeIcon: ""
    property int badgeCount: 0

    property bool compact: false
    property bool preferSymbolic: !root._nav
    property bool tabFocus: true
    property int subtitleLines: 1
    property int imageFillMode: Image.PreserveAspectCrop

    default property alias extra: trailing.data

    signal clicked()
    signal rightClicked()
    signal activated()

    function _onTrailing(px: real, py: real): bool {
        if (!trailing.visible || trailing.width <= 0)
            return false;
        const p = trailing.mapFromItem(root, px, py);
        return p.x >= 0 && p.y >= 0 && p.x < trailing.width && p.y < trailing.height;
    }

    readonly property bool _nav: root.variant === "nav"
    readonly property real _padH: root.compact ? Tokens.spacing.sm : Tokens.spacing.md
    readonly property real _padV: root.compact ? Tokens.spacing.xs : Tokens.spacing.sm
    readonly property int _glyph: root.compact ? Tokens.icon.sm : Tokens.icon.md
    readonly property color _fg: {
        if (root.destructive)
            return Colors.color.error;
        if (!root.selected)
            return Colors.color.onSurface;
        return root._nav ? Chrome.navSelected.fg : Chrome.tonal.fg;
    }
    readonly property color _iconColor: {
        if (root.destructive)
            return Colors.color.error;
        return Colors.color.primary;
    }

    implicitHeight: {
        if (root.compact)
            return Tokens.spacing.xxl;
        const minH = Tokens.spacing.xxl + Tokens.spacing.md * 2;
        return Math.max(minH, body.implicitHeight + root._padV * 2);
    }
    implicitWidth: root.compact ? Tokens.spacing.xxl * 7 : Tokens.spacing.xxl * 10
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.tabFocus && root.enabled && root.hoverHighlight
    Accessible.role: root.hoverHighlight ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.titleKey.length > 0 ? I18n.t(root.titleKey, root.titleParams) : root.titleValue
    Accessible.description: root.badgeCount > 0 ? String(root.badgeCount) : ""
    Accessible.onPressAction: {
        if (root.hoverHighlight)
            root.clicked();
    }

    Keys.onPressed: (event) => {
        if (!root.hoverHighlight)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root._nav ? Tokens.radius.full : Tokens.radius.small
        color: {
            if (root.selected)
                return root._nav ? Chrome.navSelected.bg : Chrome.tonal.bg;
            return "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root._nav ? Tokens.radius.full : Tokens.radius.small
        color: Colors.color.primary
        opacity: root.selected || !root.hoverHighlight ? 0 : Chrome.stateLayer(ma.containsMouse, false)
    }

    MouseArea {
        id: ma
        z: 3
        anchors.fill: parent
        anchors.rightMargin: trailing.visible ? trailing.width + root._padH : 0
        enabled: root.enabled && root.hoverHighlight
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            ring.markPointer();
            if (root._onTrailing(mouse.x, mouse.y))
                mouse.accepted = false;
        }
        onClicked: (mouse) => {
            if (root._onTrailing(mouse.x, mouse.y))
                return;
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onDoubleClicked: (mouse) => {
            if (root._onTrailing(mouse.x, mouse.y))
                return;
            root.activated();
        }
    }

    RowLayout {
        id: body
        z: 0
        anchors.fill: parent
        anchors.leftMargin: root._padH
        anchors.rightMargin: root._padH
        anchors.topMargin: root._padV
        anchors.bottomMargin: root._padV
        spacing: root.compact ? Tokens.spacing.sm : Tokens.spacing.md

        Rectangle {
            visible: root.imageSource.length > 0 && thumb.status === Image.Ready
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.imageSize
            Layout.preferredHeight: root.imageSize
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                id: thumb
                anchors.fill: parent
                source: root.imageSource
                fillMode: root.imageFillMode
                asynchronous: true
                sourceSize.width: root.imageSize
                sourceSize.height: root.imageSize
            }
        }

        MIcon {
            visible: (root.iconName.length > 0 || root.iconSource.length > 0)
                && thumb.status !== Image.Ready
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root._glyph
            Layout.preferredHeight: root._glyph
            name: root.iconSource.length > 0 ? "" : root.iconName
            source: root.iconSource
            size: root._glyph
            tint: root.tintIcon && root.iconSource.length === 0
            preferSymbolic: root.preferSymbolic && root.iconSource.length === 0
            color: root._iconColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs

                MText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    key: root.titleKey
                    params: root.titleParams
                    value: root.titleValue
                    styleName: root.compact ? "bodyMedium" : "bodyLarge"
                    color: root._fg
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                MIcon {
                    id: titleBadge
                    visible: root.badgeIcon.length > 0
                    name: root.badgeIcon
                    size: Tokens.icon.xs
                    color: Colors.color.onSurfaceVariant
                }
            }

            MText {
                visible: root.subtitleKey.length > 0 || root.subtitleValue.length > 0
                key: root.subtitleKey
                params: root.subtitleParams
                value: root.subtitleValue
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.maximumHeight: visible ? implicitHeight : 0
                wrapMode: root.subtitleLines > 1 ? Text.WordWrap : Text.NoWrap
                maximumLineCount: Math.max(1, root.subtitleLines)
                elide: Text.ElideRight
            }
        }

        MBadge {
            count: root.badgeCount
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            id: trailing
            z: 2
            spacing: Tokens.spacing.xs
            visible: implicitWidth > 0
            Layout.fillWidth: false
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MFocusRing {
        id: ring
        radius: root._nav ? Tokens.radius.full : Tokens.radius.small
        active: ring.parent && ring.parent.activeFocus && ring._shown && !ring._pointer
            && (root._nav || (!root.compact && root.hoverHighlight))
        ringColor: Colors.color.primary
    }
}
