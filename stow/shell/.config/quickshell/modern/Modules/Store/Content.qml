// Discover / results pane. Arrow keys walk install buttons the same
// way Settings walks its page; Left/Up past the first control returns
// to the category list.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

FocusScope {
    id: root

    property bool _pointer: false

    signal navRequested()

    function focusFirst() {
        if (!walk.focusFirst())
            root.forceActiveFocus();
    }

    function arrowMove(dx: int, dy: int): bool {
        if (SelectMenus.current)
            return false;
        if (walk.move(dx, dy))
            return true;
        if (dx < 0 || dy < 0)
            root.navRequested();
        return true;
    }

    MFocusWalk {
        id: walk
        scope: root
        flick: detail.visible ? detail.flick : (discover.visible ? discover.flick : results.flick)
    }

    onActiveFocusChanged: {
        if (!root.activeFocus || walk.ownsFocus() || root._pointer)
            return;
        root.focusFirst();
    }

    Keys.onPressed: (event) => {
        if (SelectMenus.current)
            return;
        if (event.key === Qt.Key_Down)
            root.arrowMove(0, 1);
        else if (event.key === Qt.Key_Up)
            root.arrowMove(0, -1);
        else if (event.key === Qt.Key_Right)
            root.arrowMove(1, 0);
        else if (event.key === Qt.Key_Left)
            root.arrowMove(-1, 0);
        else if (event.key === Qt.Key_Home)
            walk.focusFirst(true);
        else if (event.key === Qt.Key_End)
            walk.focusLast(true);
        else
            return;
        event.accepted = true;
    }

    Discover {
        id: discover
        anchors.fill: parent
        visible: Store.detailName.length === 0 && Store.query.trim().length === 0 && Store.categoryId === "discover"
    }

    Results {
        id: results
        anchors.fill: parent
        visible: Store.detailName.length === 0 && (Store.query.trim().length > 0 || Store.categoryId !== "discover")
    }

    Detail {
        id: detail
        anchors.fill: parent
        visible: Store.detailName.length > 0
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        onPressed: (mouse) => {
            root._pointer = true;
            root.forceActiveFocus();
            mouse.accepted = false;
            Qt.callLater(() => {
                root._pointer = false;
            });
        }
    }
}
