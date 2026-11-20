import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property string query: ""
    property string categoryId: "applications"

    signal queryEdited(string text)
    signal picked(string id)
    signal closed()

    function focusSearch() {
        nav.focusSearch();
    }

    MWindowShell {
        anchors.fill: parent
        titleKey: "cheatsheet.title"
        iconName: "modern-cheatsheet-symbolic"
        titleColumnWidth: Tokens.spacing.xxl * 9
        onClosed: root.closed()

        RowLayout {
            spacing: Tokens.spacing.lg

            MPane {
                Layout.preferredWidth: Tokens.spacing.xxl * 9
                Layout.fillHeight: true

                Nav {
                    id: nav
                    anchors.fill: parent
                    categoryId: root.categoryId
                    tabTarget: bindsScope
                    onQueryEdited: (t) => root.queryEdited(t)
                    onPicked: (id) => root.picked(id)
                    onContentRequested: bindsScope.focusFirst()
                }
            }

            FocusScope {
                id: bindsScope
                property bool _pointer: false
                Layout.fillWidth: true
                Layout.fillHeight: true

                function focusFirst() {
                    if (!bindWalk.focusFirst(true))
                        bindsScope.forceActiveFocus();
                }

                function arrowMove(dx: int, dy: int): bool {
                    if (bindWalk.move(dx, dy))
                        return true;
                    if (dx < 0 || dy < 0)
                        nav.focusActive();
                    return true;
                }

                onActiveFocusChanged: {
                    if (!bindsScope.activeFocus || bindWalk.ownsFocus() || bindsScope._pointer)
                        return;
                    bindsScope.focusFirst();
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down)
                        bindsScope.arrowMove(0, 1);
                    else if (event.key === Qt.Key_Up)
                        bindsScope.arrowMove(0, -1);
                    else if (event.key === Qt.Key_Right)
                        bindsScope.arrowMove(1, 0);
                    else if (event.key === Qt.Key_Left)
                        bindsScope.arrowMove(-1, 0);
                    else if (event.key === Qt.Key_Home)
                        bindWalk.focusFirst(true);
                    else if (event.key === Qt.Key_End)
                        bindWalk.focusLast(true);
                    else
                        return;
                    event.accepted = true;
                }

                MFocusWalk {
                    id: bindWalk
                    scope: bindsScope
                    flick: binds.flick
                }

                Binds {
                    id: binds
                    anchors.fill: parent
                    query: root.query
                    categoryId: root.categoryId
                }
            }
        }
    }
}
