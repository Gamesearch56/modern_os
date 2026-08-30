import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property string query: ""
    property var results: []
    property int currentIndex: 0

    signal queryEdited(string text)
    signal picked(int index)
    signal activated(int index)
    signal closed()

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    function focusSearch() {
        search.forceActiveFocus();
    }

    readonly property real _stackGap: Tokens.spacing.md
    readonly property real _searchY: Math.max(
        Tokens.spacing.xl,
        (root.height - search.implicitHeight) / 2 - (Tokens.spacing.xxl * 6 + Tokens.spacing.xs * 2)
    ) + Tokens.spacing.xxl + Tokens.spacing.sm
    readonly property real _belowSearch: Math.max(
        0,
        root.height - root._searchY - search.implicitHeight - root._stackGap - Tokens.spacing.xl
    )

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.color.scrim
        opacity: root._shown ? Tokens.overlay.scrim : 0

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasized
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Item {
        id: wrap
        width: Tokens.spacing.xxl * 16
        height: stack.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: root._searchY
        scale: Motion.overlayScale(root._shown)
        opacity: Motion.overlayOpacity(root._shown)
        transformOrigin: Item.Top

        Behavior on opacity {
            enabled: Motion.overlaysFade
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: root._shown
                    ? Motion.easingEmphasizedDecelerate
                    : Motion.easingEmphasizedAccelerate
            }
        }
        Behavior on scale {
            enabled: Motion.overlaysZoom
            SpringAnimation {
                spring: Motion.springBouncy.spring
                damping: Motion.springBouncy.damping
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: stack
            width: parent.width
            spacing: Tokens.spacing.md

            Search {
                id: search
                Layout.fillWidth: true
                onQueryEdited: (t) => root.queryEdited(t)
                onAccepted: {
                    if (root.results.length > 0)
                        root.activated(root.currentIndex);
                }
                onEscaped: root.closed()
                onDownPressed: {
                    if (root.results.length > 0)
                        root.picked(Math.min(root.results.length - 1, root.currentIndex + 1));
                }
                onUpPressed: {
                    if (root.results.length > 0)
                        root.picked(Math.max(0, root.currentIndex - 1));
                }
            }

            Rectangle {
                id: card
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                    results.implicitHeight + Tokens.spacing.md * 2,
                    root._belowSearch
                )
                color: Colors.color.surface
                radius: Tokens.radius.medium
                border.color: Colors.color.outlineVariant
                border.width: Tokens.stroke.hairline
                clip: true
                opacity: Config.design.transparency ?? 0.85

                Results {
                    id: results
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.md
                    model: root.results
                    currentIndex: root.currentIndex
                    searching: root.query.trim().length > 0
                    onPicked: (i) => root.picked(i)
                    onActivated: (i) => root.activated(i)
                }
            }
        }
    }
}
