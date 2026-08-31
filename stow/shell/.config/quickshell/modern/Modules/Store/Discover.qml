import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property int columns: Math.max(2, Math.floor(width / (Tokens.spacing.xxl * 8)))
    readonly property bool empty: !Store.loading && Store.featured.length === 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MSectionHeader {
            key: "store.popular"
            hintKey: "store.hintUpdates"
            styleName: "titleMedium"
            topMargin: 0
        }

        MLinearProgress {
            visible: Store.loading
            Layout.fillWidth: true
            indeterminate: true
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.empty
            cellWidth: width / root.columns
            cellHeight: Tokens.spacing.xxl * 9
            boundsBehavior: Flickable.StopAtBounds
            model: Store.featured.length
            delegate: Item {
                required property int index
                readonly property var pkg: Store.featured[index] || ({})
                readonly property bool on: !!(pkg && pkg.installed)
                readonly property string name: String(pkg && pkg.name || "")
                width: grid.cellWidth
                height: grid.cellHeight

                MCard {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.xs
                    level: 1

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.sm

                        MIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: name.length ? name : "package-x-generic-symbolic"
                            size: Tokens.spacing.xxl * 2
                            tint: false
                            preferSymbolic: false
                        }
                        MText {
                            value: name
                            styleName: "titleSmall"
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        MText {
                            value: String(pkg && pkg.desc || "")
                            styleName: "bodySmall"
                            color: Colors.color.onSurfaceVariant
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                        MButton {
                            Layout.alignment: Qt.AlignHCenter
                            kind: on ? "destructive" : "filled"
                            key: on ? "store.remove" : "store.install"
                            enabled: Store.mutating.length === 0
                            onClicked: {
                                if (on)
                                    Store.requestRemove(name);
                                else
                                    Store.requestInstall(name);
                            }
                        }
                    }
                }
            }
        }

        MEmptyState {
            visible: root.empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "system-software-install-symbolic"
            titleKey: "store.empty"
            hintKey: "store.emptyHint"
        }
    }
}
