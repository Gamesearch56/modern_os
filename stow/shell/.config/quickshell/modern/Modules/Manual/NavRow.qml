import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

// One sidebar row: a part heading (user manual, reference), a section
// heading inside it, or a document. Headings are exposed as headings so
// a screen reader can jump between them.
Item {
    id: row

    required property int index
    required property var rowData
    property bool selected: false
    property alias navItem: navItem
    readonly property string kind: String(row.rowData.kind || "")
    readonly property bool _doc: row.kind === "doc"

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: row._doc ? navItem.implicitHeight : heading.implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.topMargin: row.index === 0 ? 0 : row.kind === "part" ? Tokens.spacing.xl : row.kind === "section" ? Tokens.spacing.md : 0
    Layout.bottomMargin: row._doc ? 0 : Tokens.spacing.xs

    MText {
        id: heading
        visible: !row._doc
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.sm
        key: row._doc ? "" : String(row.rowData.key || "")
        styleName: row.kind === "part" ? "titleSmall" : "labelSmall"
        color: row.kind === "part" ? Colors.color.primary : Colors.color.onSurfaceVariant
        font.capitalization: row.kind === "section" ? Font.AllUppercase : Font.MixedCase
        elide: Text.ElideRight
        Accessible.role: Accessible.Heading
        Accessible.name: heading.text
    }

    MListItem {
        id: navItem
        visible: row._doc
        width: row.width
        variant: "nav"
        tabFocus: false
        titleValue: !row._doc ? "" : row.rowData.number > 0
            ? I18n.t("manual.chapter", { number: row.rowData.number, title: row.rowData.title })
            : String(row.rowData.title || "")
        titleLines: 2
        selected: row.selected
        Accessible.selected: row.selected
        onClicked: row.clicked()
    }
}
