import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: root

    property string query: ""
    property string categoryId: "applications"

    IpcHandler {
        target: "cheatsheet"
        function toggle() { Cheatsheet.toggle(); }
        function show() { Cheatsheet.show(); }
        function hide() { Cheatsheet.hide(); }
    }

    function _moveCategory(delta: int) {
        const cats = CheatsheetModel.categories(root.query);
        if (!cats || cats.length === 0)
            return;
        let i = 0;
        for (; i < cats.length; i++) {
            if (cats[i].id === root.categoryId)
                break;
        }
        if (i >= cats.length)
            i = 0;
        const n = Math.max(0, Math.min(cats.length - 1, i + delta));
        root.categoryId = cats[n].id;
    }

    function _syncCategory() {
        const cats = CheatsheetModel.categories(root.query);
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === root.categoryId)
                return;
        }
        root.categoryId = cats.length > 0 ? cats[0].id : "applications";
    }

    LazyLoader {
        active: Cheatsheet.open

        FloatingWindow {
            id: win
            visible: Cheatsheet.open
            title: "modern.cheatsheet"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 32 + Tokens.spacing.lg
            implicitHeight: Tokens.spacing.xxl * 22 + Tokens.spacing.lg

            onVisibleChanged: {
                if (visible) {
                    win.requestActivate();
                } else {
                    root.query = "";
                    root.categoryId = "applications";
                    Cheatsheet.hide();
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.color.surface
                radius: Tokens.radius.medium
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "cheatsheet.title"
                    subtitleValue: User.displayName
                    titleColumnWidth: Tokens.spacing.xxl * 9
                    onClosed: Cheatsheet.hide()
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.lg

                    MPane {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true

                        Nav {
                            anchors.fill: parent
                            categoryId: root.categoryId
                            onQueryEdited: (t) => {
                                root.query = t;
                                root._syncCategory();
                            }
                            onPicked: (id) => root.categoryId = id
                        }
                    }

                    Binds {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        query: root.query
                        categoryId: root.categoryId
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Cheatsheet.hide()
            }
            Shortcut {
                sequence: "Up"
                onActivated: root._moveCategory(-1)
            }
            Shortcut {
                sequence: "Down"
                onActivated: root._moveCategory(1)
            }
        }
    }
}
