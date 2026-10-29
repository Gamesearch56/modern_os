import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool installed: Store.categoryId === "installed" && Store.query.trim().length === 0
    readonly property bool empty: !Store.loading && Store.results.length === 0 && (!root.installed || Store.systemPkgs.length === 0)
    readonly property Flickable flick: installedPane.visible ? installedPane : listView
    property real _keepY: 0
    property bool _keep: false

    function _maybeMore() {
        if (root._keep)
            return;
        if (Store.hasMore && !Store.loadingMore && !Store.loading)
            Store.loadMore();
    }

    function _restoreY() {
        if (!root._keep)
            return;
        listView.contentY = root._keepY;
        pinTimer.restart();
    }

    Connections {
        target: Store
        function onListWillGrow() {
            root._keepY = listView.contentY;
            root._keep = true;
        }
        function onListDidGrow() {
            root._restoreY();
        }
    }

    Timer {
        id: pinTimer
        interval: Motion.shortMs
        onTriggered: {
            if (!root._keep)
                return;
            listView.contentY = root._keepY;
            root._keep = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        MText {
            visible: Store.query.trim().length > 0
            key: "store.resultsTitle"
            params: ({ q: Store.query.trim() })
            styleName: "titleMedium"
            Layout.fillWidth: true
        }

        MText {
            visible: Store.query.trim().length === 0
            key: "store.categories." + Store.categoryId
            styleName: "titleMedium"
            Layout.fillWidth: true
        }

        MLinearProgress {
            visible: Store.loading && !Store.loadingMore
            Layout.fillWidth: true
            indeterminate: true
        }

        Item {
            visible: !root.empty && !root.installed
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: Tokens.spacing.xs
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                model: Store.results.length
                onContentYChanged: {
                    if (root._keep && Math.abs(contentY - root._keepY) > 0.5)
                        contentY = root._keepY;
                }
                onAtYEndChanged: if (atYEnd && !root._keep) root._maybeMore()
                onContentHeightChanged: {
                    if (root._keep || Store.loadingMore || Store.loading)
                        return;
                    if (contentHeight <= height)
                        root._maybeMore();
                }
                delegate: ColumnLayout {
                    id: wrap
                    required property int index
                    width: ListView.view.width
                    spacing: Tokens.spacing.sm

                    PkgRow {
                        Layout.fillWidth: true
                        pkg: Store.results[wrap.index] || ({})
                        removable: !Store.isSystem(String(pkg && pkg.name || ""))
                    }

                    Seam {
                        visible: wrap.index === Store.newFrom - 1 && Store.newFrom > 0
                        Layout.fillWidth: true
                    }
                }
                footer: Item {
                    width: listView.width
                    height: footCol.implicitHeight

                    ColumnLayout {
                        id: footCol
                        width: parent.width
                        spacing: Tokens.spacing.md

                        ColumnLayout {
                            visible: Store.listEnd && !Store.loading && !Store.loadingMore
                            Layout.fillWidth: true
                            Layout.topMargin: Tokens.spacing.xl
                            Layout.bottomMargin: Tokens.spacing.lg
                            spacing: Tokens.spacing.sm

                            MText {
                                key: "store.listEnd"
                                styleName: "titleMedium"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            MHint {
                                key: "store.listEndHint"
                                styleName: "bodyMedium"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: Store.loadingMore
                enabled: Store.loadingMore
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: Colors.color.surfaceContainer
                height: moreCol.implicitHeight + Tokens.spacing.md * 2

                ColumnLayout {
                    id: moreCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.spacing.md
                    anchors.rightMargin: Tokens.spacing.md
                    spacing: Tokens.spacing.sm

                    MLinearProgress {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Tokens.spacing.md
                        indeterminate: true
                    }
                    MText {
                        key: "store.loadingMore"
                        styleName: "titleSmall"
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Flickable {
            id: installedPane
            visible: !root.empty && root.installed
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: installedCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: installedCol
                width: parent.width
                spacing: Tokens.spacing.xs

                Repeater {
                    model: Store.results.length
                    PkgRow {
                        required property int index
                        Layout.fillWidth: true
                        pkg: Store.results[index] || ({})
                        forceInstalled: true
                    }
                }

                SystemGroup {
                    packages: Store.systemPkgs
                }
            }
        }

        MEmptyState {
            visible: root.empty
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "system-software-install-symbolic"
            titleKey: "store.empty"
            hintKey: Store.query.trim().length > 0 ? "store.emptySearch" : "store.emptyHint"
        }
    }
}
