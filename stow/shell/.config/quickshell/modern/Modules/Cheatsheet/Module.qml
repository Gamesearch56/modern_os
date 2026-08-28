import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    IpcHandler {
        target: "cheatsheet"
        function toggle() { Cheatsheet.toggle(); }
        function show() { Cheatsheet.show(); }
        function hide() { Cheatsheet.hide(); }
    }

    component CategoryColumn: ColumnLayout {
        required property var cats
        spacing: Tokens.spacing.sm
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop

        Repeater {
            model: cats
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Tokens.spacing.sm

                MSectionHeader {
                    key: "cheatsheet.category." + modelData.id
                    styleName: "titleSmall"
                    Layout.topMargin: Tokens.spacing.md
                }

                Repeater {
                    model: modelData.items
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.md

                        Row {
                            Layout.preferredWidth: Tokens.spacing.xxl * 8
                            spacing: Tokens.spacing.xs
                            Repeater {
                                model: modelData.caps
                                MKeycap {
                                    required property string modelData
                                    value: modelData
                                }
                            }
                        }

                        MText {
                            key: "cheatsheet.action." + modelData.action
                            styleName: "bodyMedium"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }
    }

    LazyLoader {
        active: Cheatsheet.open

        PanelWindow {
            visible: Cheatsheet.open
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            MOverlay {
                open: Cheatsheet.open
                titleKey: "cheatsheet.title"
                cardWidth: Tokens.spacing.xxl * 22
                cardHeight: Tokens.spacing.xxl * 18
                onClosed: Cheatsheet.hide()

                ColumnLayout {
                    spacing: Tokens.spacing.md

                    MSearchField {
                        id: search
                        Layout.fillWidth: true
                        placeholderKey: "cheatsheet.search"
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: cols.implicitHeight

                        RowLayout {
                            id: cols
                            width: parent.width
                            spacing: Tokens.spacing.xl
                            CategoryColumn {
                                cats: CheatsheetModel.grouped(search.text).left
                            }
                            CategoryColumn {
                                cats: CheatsheetModel.grouped(search.text).right
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Cheatsheet.hide()
            }
        }
    }
}
