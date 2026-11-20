import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property string query: ""
    property var results: []
    property var catalog: []
    property int currentIndex: 0

    signal queryEdited(string text)
    signal picked(int index)
    signal activated(int index)
    signal activatedApp(int index)
    signal closed()

    property bool appsOpen: false
    property bool _buttonOn: false
    property int appsIndex: 0
    property real _escAt: 0

    property bool _entered: false
    readonly property bool _shown: root._entered

    Component.onCompleted: root._entered = true

    function focusSearch() {
        search.forceActiveFocus();
    }

    // Escape is delivered both to the search field and to the window
    // shortcut. The first call closes the grid; the second, in the same
    // keypress, must not also close the launcher.
    function takeEscape(): bool {
        const now = Date.now();
        if (root.appsOpen) {
            root.appsOpen = false;
            root._escAt = now;
            return true;
        }
        if (now - root._escAt < 80)
            return true;
        root._escAt = now;
        return false;
    }

    function arrowMove(dx: int, dy: int): bool {
        if (!root.appsOpen)
            return false;
        root.appsIndex = apps.step(dx, dy);
        return true;
    }

    readonly property real _buttonBlock: Tokens.spacing.xxl + Tokens.spacing.md + Tokens.spacing.md
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
            cursorShape: Qt.PointingHandCursor
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
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
                onQueryEdited: (t) => {
                    root._buttonOn = false;
                    root.appsIndex = 0;
                    root.queryEdited(t);
                }
                onAccepted: {
                    if (root.appsOpen) {
                        if (root.catalog.length > 0)
                            root.activatedApp(root.appsIndex);
                        return;
                    }
                    if (root._buttonOn) {
                        root.appsOpen = true;
                        root.appsIndex = 0;
                        return;
                    }
                    if (root.results.length > 0)
                        root.activated(root.currentIndex);
                }
                onEscaped: {
                    if (!root.takeEscape())
                        root.closed();
                }
                onDownPressed: {
                    if (root.appsOpen) {
                        root.appsIndex = apps.step(0, 1);
                        return;
                    }
                    if (root._buttonOn)
                        return;
                    if (root.results.length === 0 || root.currentIndex >= root.results.length - 1)
                        root._buttonOn = true;
                    else
                        root.picked(root.currentIndex + 1);
                }
                onUpPressed: {
                    if (root.appsOpen) {
                        root.appsIndex = apps.step(0, -1);
                        return;
                    }
                    if (root._buttonOn) {
                        root._buttonOn = false;
                        if (root.results.length > 0)
                            root.picked(root.results.length - 1);
                        return;
                    }
                    if (root.results.length > 0)
                        root.picked(Math.max(0, root.currentIndex - 1));
                }
            }

            Item {
                id: card
                Layout.fillWidth: true
                Layout.preferredHeight: {
                    const room = Math.max(0, root._belowSearch - root._buttonBlock);
                    const full = results.maxImplicitHeight + Tokens.spacing.md * 2;
                    if (root.appsOpen)
                        return Math.min(full, room);
                    return Math.min(results.implicitHeight + Tokens.spacing.md * 2, room);
                }
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.medium
                    color: Colors.color.surface
                    opacity: Chrome.washOpacity
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.medium
                    color: "transparent"
                    border.color: Colors.color.outlineVariant
                    border.width: Tokens.stroke.hairline
                }

                Results {
                    id: results
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.md
                    visible: !root.appsOpen
                    model: root.results
                    currentIndex: root._buttonOn ? -1 : root.currentIndex
                    searching: root.query.trim().length > 0
                    onPicked: (i) => root.picked(i)
                    onActivated: (i) => root.activated(i)
                }
            }

            AllApps {
                id: apps
                Layout.alignment: Qt.AlignHCenter
                host: wrap
                open: root.appsOpen
                armed: root._buttonOn
                model: root.catalog
                currentIndex: root.appsIndex
                showIcons: Config.launcher.showIcons ?? true
                popupHeight: card.height + stack.spacing - Tokens.spacing.xs
                onToggled: {
                    root.appsOpen = !root.appsOpen;
                    if (root.appsOpen) {
                        root._buttonOn = false;
                        root.appsIndex = 0;
                    }
                    Qt.callLater(root.focusSearch);
                }
                onActivated: (i) => root.activatedApp(i)
                onRetreated: {
                    root._buttonOn = false;
                    root.focusSearch();
                    if (root.results.length > 0)
                        root.picked(root.results.length - 1);
                }
            }
        }
    }
}
