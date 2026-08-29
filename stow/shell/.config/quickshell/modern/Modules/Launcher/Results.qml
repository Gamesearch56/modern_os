import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool searching: false

    signal picked(int index)
    signal activated(int index)

    readonly property real _rowH: Tokens.spacing.xxl + Tokens.spacing.md * 2
    readonly property int _maxRows: Config.launcher.resultCount ?? 9
    readonly property int _count: root.model.length
    readonly property int _rows: root._count === 0
        ? 2
        : Math.min(root._count, root._maxRows)

    implicitHeight: label.implicitHeight + Tokens.spacing.sm
        + root._rows * root._rowH
        + Math.max(0, root._rows - 1) * Tokens.spacing.xxs
    readonly property real maxImplicitHeight: label.implicitHeight + Tokens.spacing.sm
        + root._maxRows * root._rowH
        + Math.max(0, root._maxRows - 1) * Tokens.spacing.xxs

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MText {
            id: label
            key: root.searching ? "launcher.results" : "launcher.mostUsed"
            styleName: "labelSmall"
            color: Colors.color.onSurfaceVariant
            font.capitalization: Font.AllUppercase
            Layout.fillWidth: true
        }

        ListView {
            id: list
            visible: root.model.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.xxs
            boundsBehavior: Flickable.StopAtBounds
            model: root._count
            currentIndex: root.currentIndex
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Motion.short()

            delegate: MListItem {
                required property int index
                readonly property var hit: root.model[index] || ({})
                width: list.width
                iconName: {
                    if (!(Config.launcher.showIcons ?? true))
                        return "";
                    return hit.icon || "application-x-executable";
                }
                tintIcon: hit.kind === "settings" || hit.kind === "power"
                titleValue: hit.name
                subtitleValue: (Config.launcher.showDescriptions ?? true)
                    ? (hit.genericName || "")
                    : ""
                selected: root.currentIndex === index
                onClicked: {
                    root.picked(index);
                    root.activated(index);
                }
                onActivated: root.activated(index)
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.medium()
                    easing.bezierCurve: Motion.easingEmphasizedDecelerate
                }
                NumberAnimation {
                    property: "y"
                    duration: Motion.medium()
                    easing.bezierCurve: Motion.easingEmphasizedDecelerate
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Motion.short()
                    easing.bezierCurve: Motion.easingEmphasizedAccelerate
                }
                NumberAnimation {
                    property: "y"
                    duration: Motion.short()
                    easing.bezierCurve: Motion.easingEmphasizedAccelerate
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Motion.short()
                    easing.bezierCurve: Motion.easingStandard
                }
            }

            onCurrentIndexChanged: {
                if (list.currentIndex >= 0)
                    list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            }
        }

        MEmptyState {
            visible: root.model.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "edit-find-symbolic"
            titleKey: "launcher.noResults"
        }
    }
}
