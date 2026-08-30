// One row in a list. `variant` row uses tonal selected; nav uses a
// filled primary pill so Settings sidebar matches Material You.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property string iconName: ""
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

    default property alias extra: trailing.data

    signal clicked()
    signal rightClicked()
    signal activated()

    readonly property bool _nav: root.variant === "nav"
    readonly property color _fg: {
        if (root.destructive)
            return Colors.color.error;
        if (!root.selected)
            return Colors.color.onSurface;
        return root._nav ? Chrome.navSelected.fg : Chrome.tonal.fg;
    }

    implicitHeight: root.imageSource.length > 0
        ? root.imageSize + Tokens.spacing.md * 2
        : Tokens.spacing.xxl + Tokens.spacing.md * 2
    implicitWidth: Tokens.spacing.xxl * 10
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled && root.hoverHighlight
    Accessible.role: Accessible.Button
    Accessible.name: root.titleKey.length > 0 ? I18n.t(root.titleKey, root.titleParams) : root.titleValue
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
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
        opacity: root.selected || !root.hoverHighlight ? 0 : Chrome.stateLayer(hover.hovered, false)
    }

    HoverHandler {
        id: hover
        enabled: root.enabled && root.hoverHighlight
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.hoverHighlight ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (root.hoverHighlight)
                root.forceActiveFocus();
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onDoubleClicked: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        anchors.topMargin: Tokens.spacing.sm
        anchors.bottomMargin: Tokens.spacing.sm
        spacing: Tokens.spacing.md

        Rectangle {
            visible: root.imageSource.length > 0
            Layout.preferredWidth: root.imageSize
            Layout.preferredHeight: root.imageSize
            radius: Tokens.radius.small
            color: Colors.color.surfaceContainerHighest
            clip: true

            Image {
                anchors.fill: parent
                source: root.imageSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: root.imageSize
                sourceSize.height: root.imageSize
            }
        }

        MIcon {
            visible: root.iconName.length > 0 && root.imageSource.length === 0
            name: root.iconName
            size: Tokens.icon.md
            tint: root.tintIcon
            preferSymbolic: !root._nav
            color: root._fg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                implicitHeight: titleRow.implicitHeight

                Row {
                    id: titleRow
                    spacing: Tokens.spacing.xs
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    MText {
                        key: root.titleKey
                        params: root.titleParams
                        value: root.titleValue
                        styleName: "bodyLarge"
                        color: root._fg
                        width: {
                            const extra = titleBadge.visible ? titleBadge.width + titleRow.spacing : 0;
                            return Math.min(implicitWidth, Math.max(0, titleRow.parent.width - extra));
                        }
                    }
                    MIcon {
                        id: titleBadge
                        visible: root.badgeIcon.length > 0
                        name: root.badgeIcon
                        size: Tokens.icon.xs
                        color: Colors.color.onSurfaceVariant
                    }
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
            }
        }

        Item {
            id: trailing
            visible: children.length > 0
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MFocusRing {
        radius: root._nav ? Tokens.radius.full : Tokens.radius.small
        active: !root._nav && (root.selected || (root.hoverHighlight && (root.activeFocus || hover.hovered)))
        ringColor: Colors.color.primary
    }
}
