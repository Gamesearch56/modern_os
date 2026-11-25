import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"
import "../../Widgets"
import "viewops.js" as Ops

// Facts about the shown picture, beside it rather than over it.
Rectangle {
    id: root

    property real pixelWidth: 0
    property real pixelHeight: 0

    readonly property var _size: Ops.sizeParts(ViewerDoc.info.size)
    readonly property var _when: Ops.mtimeDate(ViewerDoc.info.mtime)
    readonly property var rows: [
        { key: "viewer.info.dimensions", value: root.pixelWidth > 0
            ? I18n.t("viewer.info.pixels", { width: root.pixelWidth, height: root.pixelHeight }) : "" },
        { key: "viewer.info.size", value: root._size ? I18n.t("viewer.units." + root._size.unit, { value: root._number(root._size.value) }) : "" },
        { key: "viewer.info.type", value: String(ViewerDoc.info.mime || "") },
        { key: "viewer.info.modified", value: root._when
            ? DateTime.formatDate(root._when, Config.language.dateFormat) + " "
                + DateTime.formatTime(root._when, Config.language.timeFormat, false) : "" },
        { key: "viewer.info.folder", value: ViewerDoc.folder.length ? XdgDirs.toTilde(ViewerDoc.folder) : "" }
    ]

    function _number(v: real): string {
        return Number(v).toLocaleString(Qt.locale(I18n.activeLang), "f", Number.isInteger(v) ? 0 : 1);
    }

    implicitWidth: Tokens.spacing.xxl * 7
    implicitHeight: column.implicitHeight + Tokens.spacing.lg * 2
    radius: Tokens.radius.large
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline
    Accessible.role: Accessible.Pane
    Accessible.name: I18n.t("viewer.info.title")

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Tokens.spacing.lg
        spacing: Tokens.spacing.sm

        MText {
            key: "viewer.info.title"
            styleName: "titleSmall"
        }

        Repeater {
            model: root.rows
            delegate: ColumnLayout {
                required property var modelData
                visible: modelData.value.length > 0
                Layout.fillWidth: true
                spacing: 0

                MText {
                    key: modelData.key
                    styleName: "labelMedium"
                    color: Colors.color.onSurfaceVariant
                }
                MText {
                    Layout.fillWidth: true
                    value: modelData.value
                    styleName: "bodyMedium"
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
