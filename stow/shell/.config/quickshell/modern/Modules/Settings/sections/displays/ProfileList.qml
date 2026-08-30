import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    id: root

    property string selectedDesc: ""

    signal picked(string desc)

    readonly property var mons: {
        void Hypr.monitors;
        void Hypr.monitorGen;
        return Hypr.monitors?.values ?? [];
    }

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    Repeater {
        model: root.mons
        MCard {
            required property var modelData
            readonly property string desc: String(modelData.description || "")
            readonly property bool active: desc.length > 0 && desc === root.selectedDesc
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: Tokens.icon.lg + Tokens.spacing.xxl * 3
            level: active ? 3 : 1
            highlighted: active

            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.xs

                MText {
                    value: modelData.description || modelData.name || ""
                    styleName: "titleSmall"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                }
                MIcon {
                    name: "video-display"
                    size: Tokens.icon.lg
                    color: active ? Colors.color.primary : Colors.color.onSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                }
                MText {
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    value: {
                        void Hypr.monitorGen;
                        const w = modelData.width || 0;
                        const h = modelData.height || 0;
                        const hz = Hypr.hzFor(modelData);
                        if (!w || !h)
                            return "";
                        return w + " × " + h + (hz > 0 ? (" · " + hz + " Hz") : "");
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (desc.length)
                        root.picked(desc);
                }
            }
        }
    }
}
