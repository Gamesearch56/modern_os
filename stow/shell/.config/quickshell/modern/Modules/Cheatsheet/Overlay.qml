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
                    onQueryEdited: (t) => root.queryEdited(t)
                    onPicked: (id) => root.picked(id)
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
}
