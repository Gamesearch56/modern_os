// Image tile. `current` is the keyboard/pointer selection (one at a
// time). `hoverRing` is for grids that are pointer-only (Settings
// gallery) — the wallpaper picker keeps it off so a parked cursor
// cannot draw a second ring next to the arrow-key selection.
import QtQuick
import Quickshell.Widgets
import "../Commons"

Item {
    id: root

    property url source: ""
    property bool selected: false
    property bool current: false
    property bool hoverRing: true
    property bool dimRest: true
    property bool removable: false

    property bool tabFocus: false
    // Gallery tiles ignore a second press on the current image.
    // A toggle tile (a screenshot include) sets this so Enter flips it.
    property bool activateSelected: false
    readonly property bool _ring: root.current || root.activeFocus || (root.hoverRing && !root.selected && ma.containsMouse)
    readonly property real _radius: Tokens.radius.small
    readonly property bool _removeHot: removeMa.containsMouse || removeMa.pressed
    // The grid creates cells before the window has a width. Loading then
    // sticks on the tile color, so the picture waits until the cell is real.
    readonly property bool _laidOut: root.width >= Tokens.spacing.xl && root.height >= Tokens.spacing.xl
    property int _attempt: 0
    property url _shown: ""

    signal imageFailed()

    function _arm() {
        if (!root._laidOut || !root.source.toString().length) {
            root._shown = "";
            return;
        }
        if (root._shown.toString() === root.source.toString())
            return;
        root._shown = root.source;
    }

    onSourceChanged: {
        root._attempt = 0;
        root._arm();
    }
    onWidthChanged: root._arm()
    onHeightChanged: root._arm()

    scale: (!root.dimRest || root.selected || root._ring) ? 1 : Motion.overlayScale(false)
    opacity: (!root.dimRest || root.selected || root._ring) ? 1 : (1 - Tokens.interaction.hover)
    transformOrigin: Item.Center

    Behavior on scale {
        enabled: Motion.overlaysZoom
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: Motion.easingEmphasizedDecelerate
        }
    }
    Behavior on opacity {
        enabled: Motion.overlaysFade
        NumberAnimation {
            duration: Motion.mediumMs
            easing.bezierCurve: Motion.easingStandard
        }
    }

    signal clicked()
    signal hovered()
    signal pointerMoved()
    signal removeClicked()

    activeFocusOnTab: root.tabFocus
    Accessible.role: Accessible.Button
    Accessible.onPressAction: {
        if (root.activateSelected || !root.selected)
            root.clicked();
    }
    Keys.onPressed: (event) => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        if (root.activateSelected || !root.selected)
            root.clicked();
        event.accepted = true;
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root._radius
        color: Colors.color.surfaceContainerHighest

        Image {
            id: pic
            anchors.fill: parent
            // One edge only. A square request stretches the bitmap before
            // the crop can keep the picture's shape.
            sourceSize.width: Tokens.spacing.xxl * 16
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: root._attempt === 0
            smooth: true
            source: root._shown
            onStatusChanged: {
                if (status !== Image.Error || !root._shown.toString().length)
                    return;
                if (root._attempt >= 1) {
                    root.imageFailed();
                    return;
                }
                root._attempt = 1;
                const again = root._shown;
                root._shown = "";
                Qt.callLater(() => { root._shown = again; });
            }
        }
    }

    Rectangle {
        visible: root.selected
        z: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.xs
        width: Tokens.spacing.xl
        height: Tokens.spacing.xl
        radius: Tokens.radius.full
        color: Colors.color.primary

        MIcon {
            anchors.centerIn: parent
            name: "object-select-symbolic"
            size: Tokens.icon.sm
            color: Colors.color.onPrimary
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root._radius
        color: "transparent"
        border.width: root._ring ? 0 : Tokens.stroke.hairline
        border.color: Colors.color.outlineVariant
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!root.selected)
                root.clicked();
        }
        onEntered: root.hovered()
        onPositionChanged: root.pointerMoved()
    }

    Item {
        visible: root.removable
        z: 3
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.xs
        width: Tokens.spacing.xl
        height: Tokens.spacing.xl
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("wallpaper.remove")
        Accessible.onPressAction: root.removeClicked()

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.full
            color: root._removeHot ? Colors.color.error : Colors.color.errorContainer

            Behavior on color {
                ColorAnimation {
                    duration: Motion.shortMs
                    easing.bezierCurve: Motion.easingStandard
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius.full
            color: root._removeHot ? Colors.color.onError : Colors.color.onErrorContainer
            opacity: Chrome.stateLayer(removeMa.containsMouse, removeMa.pressed)
        }

        MIcon {
            anchors.centerIn: parent
            name: "window-close"
            size: Tokens.icon.sm
            color: root._removeHot ? Colors.color.onError : Colors.color.onErrorContainer
        }

        MouseArea {
            id: removeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeClicked()
        }
    }

    MFocusRing {
        radius: root._radius
        active: root._ring
    }
}
