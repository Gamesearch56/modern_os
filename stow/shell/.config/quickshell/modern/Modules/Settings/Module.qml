// Settings app. Lazy-loaded when Services/Settings.open.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    Catalog { id: catalog }

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

            MOverlay {
                open: Settings.open
                titleKey: "settings.title"
                cardWidth: Tokens.spacing.xxl * 28
                cardHeight: Tokens.spacing.xxl * 20
                onClosed: Settings.close()

                ColumnLayout {
                    spacing: Tokens.spacing.md

                    MSearchField {
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
                            delegate: Item {
                                required property var modelData
                                width: nav.width
                                height: modelData.kind === "group" ? Tokens.spacing.xl : implicitHeight
                                implicitHeight: modelData.kind === "group" ? Tokens.spacing.xl : itemRow.implicitHeight

                                MText {
                                    visible: modelData.kind === "group"
                                    anchors.fill: parent
                                    key: modelData.key
                                    styleName: "labelSmall"
                                    color: Colors.color.onSurfaceVariant
                                }

                                MListItem {
                                    id: itemRow
                                    visible: modelData.kind === "item"
                                    width: nav.width
                                    iconName: catalog.icon(modelData.id)
                                    titleKey: "settings.sections." + modelData.id
                                    selected: Settings.sectionId === modelData.id
                                    onClicked: Settings.openAt(modelData.id, "")
                                }
                            }
                        }

                        Flickable {
                            id: pane
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: {
                                const it = sectionLoader.item;
                                if (!it)
                                    return 0;
                                return Math.max(it.implicitHeight, it.childrenRect.height);
                            }

                            Loader {
                                id: sectionLoader
                                width: pane.width
                                source: Qt.resolvedUrl("sections/" + Settings.sectionId + "/Section.qml")
                                onLoaded: {
                                    if (item)
                                        item.width = Qt.binding(() => sectionLoader.width);
                                }
                            }
                        }
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
