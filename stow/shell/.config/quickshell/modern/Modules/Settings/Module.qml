// Settings app. Lazy-loaded when Services/Settings.open; the only UI
// that asks ConfigWrite to mutate config.json. Sidebar is the section
// registry; search filters Catalog keywords (mirrors section.json).
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Catalog { id: catalog }

    readonly property var registry: catalog.ids

    LazyLoader {
        active: Settings.open

        PanelWindow {
            id: win
            visible: Settings.open
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            Rectangle {
                anchors.fill: parent
                color: Colors.color.scrim
                opacity: 0.45
                MouseArea {
                    anchors.fill: parent
                    onClicked: Settings.close()
                }
            }

            MCard {
                level: 3
                width: Math.min(Tokens.spacing.xxl * 28, win.width - Tokens.spacing.xxl)
                height: Math.min(Tokens.spacing.xxl * 20, win.height - Tokens.spacing.xxl * 2)
                anchors.centerIn: parent

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.md

                    RowLayout {
                        Layout.fillWidth: true
                        MText {
                            key: "settings.title"
                            styleName: "headlineSmall"
                            Layout.fillWidth: true
                        }
                        MIconButton {
                            iconName: "window-close"
                            onClicked: Settings.close()
                        }
                    }

                    MTextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderKey: "settings.search"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.md

                        ListView {
                            id: nav
                            Layout.preferredWidth: Tokens.spacing.xxl * 8
                            Layout.fillHeight: true
                            clip: true
                            model: catalog.filtered(search.text)
                            spacing: Tokens.spacing.xxs
                            delegate: MListItem {
                                required property var modelData
                                width: nav.width
                                iconName: catalog.icon(modelData)
                                titleKey: "settings.sections." + modelData
                                selected: Settings.sectionId === modelData
                                onClicked: Settings.openAt(modelData, "")
                            }
                        }

                        Flickable {
                            id: pane
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: sectionLoader.item ? sectionLoader.item.implicitHeight : 0

                            Loader {
                                id: sectionLoader
                                width: pane.width
                                source: Qt.resolvedUrl("sections/" + Settings.sectionId + "/Section.qml")
                            }
                        }
                    }

                    MText {
                        visible: nav.count === 0
                        key: "settings.noResults"
                        styleName: "bodyMedium"
                        color: Colors.color.onSurfaceVariant
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Settings.close()
            }
        }
    }
}
