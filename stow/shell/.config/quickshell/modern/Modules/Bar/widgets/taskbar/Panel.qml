import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

FocusScope {
    id: root
    focus: true

    property var barScreen: null
    property int currentIndex: 0
    property int menuIndex: -1
    property string menuAddress: ""
    property bool menuBackground: false
    property string menuKind: "window"
    property var menuEntry: null
    property real menuRowY: 0
    property real menuRowH: 0

    readonly property int count: Taskbar.count

    function workspaceLabel(id: int): string {
        const p = {};
        p.id = id;
        return I18n.t("bar.taskbarWorkspace", p);
    }

    function closeMenu() {
        root.menuIndex = -1;
        root.menuAddress = "";
        root.menuBackground = false;
        root.menuKind = "window";
        root.menuEntry = null;
        Qt.callLater(() => {
            root.forceActiveFocus();
            if (view.visible)
                view.forceActiveFocus();
        });
    }

    function entryAt(i: int): var {
        return (Taskbar.entries || [])[i] || null;
    }

    function focusFirst() {
        if (root._closedAt >= 0)
            return;
        const list = Taskbar.entries || [];
        let idx = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].activated) {
                idx = i;
                break;
            }
        }
        root.currentIndex = idx;
        root.closeFocus = false;
        root.forceActiveFocus();
        if (view.visible)
            view.forceActiveFocus();
        view.positionViewAtIndex(idx, ListView.Contain);
    }

    function activateCurrent() {
        const e = root.entryAt(root.currentIndex);
        if (!e)
            return;
        root.closeMenu();
        Taskbar.activate(e);
        Popups.dismiss();
        Taskbar.hide();
    }

    function closeFromMenu() {
        const i = root.menuIndex;
        root.closeMenu();
        root.closeAt(i);
    }

    function closeCurrent() {
        root.closeAt(root.currentIndex);
    }

    property int _closedAt: -1
    property int _closedCount: -1

    function closeAt(i: int) {
        const e = root.entryAt(i);
        if (!e)
            return;
        const n = root.count;
        root._closedAt = i;
        root._closedCount = n;
        Taskbar.close(e);
        if (n <= 1) {
            root.currentIndex = 0;
            root.closeFocus = false;
            return;
        }
        root.currentIndex = (i >= n - 1) ? i - 1 : i + 1;
    }

    function clickCurrentClose() {
        const obj = view.itemAtIndex(root.currentIndex);
        const row = obj && obj.clickClose ? obj : (obj ? obj.item : null);
        if (row && row.clickClose && row.clickClose())
            return;
        root.closeCurrent();
    }

    property bool closeFocus: false
    property bool _keyBusy: false
    property bool _didActivate: false

    function canCloseAt(i: int): bool { return !!root.entryAt(i); }

    function focusClose() {
        root.closeFocus = root.canCloseAt(root.currentIndex);
        return root.closeFocus;
    }

    function keepCloseFocus() {
        if (root.closeFocus && !root.canCloseAt(root.currentIndex))
            root.closeFocus = false;
    }

    function onActivateKey(event) {
        if (root.menuIndex >= 0)
            return;
        if (root._didActivate) {
            event.accepted = true;
            return;
        }
        root._didActivate = true;
        if (root.closeFocus)
            root.clickCurrentClose();
        else
            root.activateCurrent();
        event.accepted = true;
        Qt.callLater(() => {
            root._didActivate = false;
        });
    }

    function onKeys(event) {
        if (root._keyBusy || root.menuIndex >= 0)
            return;
        root._keyBusy = true;
        if (event.key === Qt.Key_Down) {
            if (root.count > 0)
                root.currentIndex = Math.min(root.count - 1, root.currentIndex + 1);
            event.accepted = true;
            root.keepCloseFocus();
        } else if (event.key === Qt.Key_Up) {
            root.currentIndex = Math.max(0, root.currentIndex - 1);
            event.accepted = true;
            root.keepCloseFocus();
        } else if (event.key === Qt.Key_Home) {
            root.currentIndex = 0;
            event.accepted = true;
            root.keepCloseFocus();
        } else if (event.key === Qt.Key_End) {
            if (root.count > 0)
                root.currentIndex = root.count - 1;
            event.accepted = true;
            root.keepCloseFocus();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.onActivateKey(event);
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.closeCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.focusClose();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.closeFocus = false;
            event.accepted = true;
        }
        root._keyBusy = false;
    }

    onCountChanged: {
        if (root.count <= 0) {
            root.currentIndex = 0;
            root.closeFocus = false;
            root._closedAt = -1;
            root._closedCount = -1;
            return;
        }
        if (root._closedAt >= 0 && (root._closedCount < 0 || root.count < root._closedCount)) {
            root.currentIndex = Math.min(root._closedAt, root.count - 1);
            root._closedAt = -1;
            root._closedCount = -1;
            root.keepCloseFocus();
        } else if (root.currentIndex >= root.count) {
            root.currentIndex = root.count - 1;
        }
        Qt.callLater(root._keepInView);
    }
    onCurrentIndexChanged: root._keepInView()

    function _keepInView() {
        if (!view.visible || root.count <= 0)
            return;
        const i = Math.min(Math.max(0, root.currentIndex), root.count - 1);
        view.positionViewAtIndex(i, ListView.Contain);
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: (event) => root.onKeys(event)
    Keys.onReturnPressed: (event) => root.onActivateKey(event)
    Keys.onEnterPressed: (event) => root.onActivateKey(event)
    Keys.onSpacePressed: (event) => root.onActivateKey(event)
    Component.onCompleted: Qt.callLater(root.focusFirst)

    BarPanelChrome {
        anchors.fill: parent
        titleKey: "bar.taskbar"

        MPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ListView {
                id: view
                anchors.fill: parent
                clip: true
                visible: root.count > 0
                spacing: Tokens.spacing.sm
                boundsBehavior: Flickable.StopAtBounds
                model: root.count
                keyNavigationEnabled: false
                focus: true
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: (event) => root.onKeys(event)
                Keys.onReturnPressed: (event) => root.onActivateKey(event)
                Keys.onEnterPressed: (event) => root.onActivateKey(event)
                Keys.onSpacePressed: (event) => root.onActivateKey(event)
                delegate: Loader {
                    id: row
                    required property int index
                    width: view.width
                    height: item ? item.implicitHeight : 0
                    source: Qt.resolvedUrl("Entry.qml")
                    onLoaded: {
                        if (!item)
                            return;
                        item.host = root;
                        item.index = Qt.binding(() => row.index);
                        item.width = Qt.binding(() => row.width);
                    }
                }
            }

            MEmptyState {
                visible: root.count === 0
                anchors.fill: parent
                iconName: "focus-windows-symbolic"
                titleKey: "bar.taskbarEmpty"
                hintKey: "bar.taskbarEmptyHint"
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.menuIndex >= 0
        source: Qt.resolvedUrl("Menu.qml")
        onLoaded: {
            if (!item)
                return;
            item.menuAddress = Qt.binding(() => root.menuAddress);
            item.menuBackground = Qt.binding(() => root.menuBackground);
            item.menuKind = Qt.binding(() => root.menuKind);
            item.menuEntry = Qt.binding(() => root.menuEntry);
            item.menuRowY = Qt.binding(() => root.menuRowY);
            item.menuRowH = Qt.binding(() => root.menuRowH);
            item.closed.connect(root.closeMenu);
            item.closeApp.connect(root.closeFromMenu);
            Qt.callLater(() => {
                if (item && item.forceActiveFocus)
                    item.forceActiveFocus();
            });
        }
    }
}
