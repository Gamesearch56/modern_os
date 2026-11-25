import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property string monitorDesc: ""
    readonly property bool _barBottom: BarLayout.position === "bottom"
    readonly property bool _barLeft: BarLayout.position === "left"

    Binding {
        target: SystemStats
        property: "watching"
        value: Notifications.panelOpen
    }

    Binding {
        target: Brightness
        property: "watching"
        value: Notifications.panelOpen
    }

    Connections {
        target: Notifications
        function onPanelOpenChanged() {
            if (Notifications.panelOpen)
                Brightness.refreshDisplays();
        }
    }

    Component.onCompleted: {
        if (Notifications.panelOpen)
            Brightness.refreshDisplays();
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.hide()
    }

    MPanelSurface {
        id: card
        width: Tokens.spacing.xxl * 16
        implicitHeight: inner.implicitHeight + Tokens.spacing.md * 2
        height: Math.min(implicitHeight, parent.height - Tokens.spacing.xl)
        anchors.right: !root._barLeft ? parent.right : undefined
        anchors.left: root._barLeft ? parent.left : undefined
        anchors.rightMargin: BarLayout.endGap ?? Tokens.spacing.md
        anchors.leftMargin: BarLayout.endGap ?? Tokens.spacing.md
        y: root._barBottom ? (parent.height - height) : 0
        scale: Motion.overlayScale(Notifications.panelOpen)

        Behavior on scale {
            NumberAnimation {
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingEmphasizedDecelerate
            }
        }

        MouseArea {
            z: -1
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: Tokens.spacing.md
            spacing: Tokens.spacing.md

            Header {}
            Toggles {}
            Sliders {
                monitorDesc: root.monitorDesc
            }
            Stats {}

            RowLayout {
                Layout.fillWidth: true
                MText {
                    key: "bar.notifications"
                    styleName: "titleSmall"
                    Layout.fillWidth: true
                }
                MButton {
                    kind: "text"
                    key: "notifications.clearAll"
                    enabled: Notifications.list.length > 0
                    onClicked: Notifications.dismissAll()
                }
            }

            MPane {
                Layout.fillWidth: true
                Layout.fillHeight: list.visible
                Layout.minimumHeight: Tokens.spacing.xxl * 4
                Layout.preferredHeight: list.visible
                    ? Math.min(list.contentHeight + Tokens.spacing.md * 2, Tokens.spacing.xxl * 16)
                    : Tokens.spacing.xxl * 6
                padding: Tokens.spacing.md

                ListView {
                    id: list
                    visible: Notifications.list.length > 0
                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.sm
                    boundsBehavior: Flickable.StopAtBounds
                    topMargin: Tokens.spacing.xs
                    bottomMargin: Tokens.spacing.xs
                    model: Notifications.list
                    delegate: MListItem {
                        required property var modelData
                        width: list.width
                        tintIcon: Notifications.displayIconSource(modelData).length === 0
                        preferSymbolic: Notifications.displayIconSource(modelData).length === 0
                        iconName: Notifications.displayIcon(modelData)
                        iconSource: Notifications.displayIconSource(modelData)
                        imageSource: Notifications.displayImage(modelData)
                        imageSize: Tokens.icon.lg
                        imageFillMode: Image.PreserveAspectFit
                        titleLines: 3
                        subtitleLines: 3
                        titleValue: modelData.summary || modelData.appName || ""
                        subtitleValue: modelData.body || ""
                        onClicked: Notifications.activate(modelData)
                        MIconButton {
                            z: 3
                            close: true
                            tabFocus: false
                            iconName: "window-close"
                            key: "bar.close"
                            size: Tokens.spacing.xl
                            iconSize: Tokens.icon.sm
                            onClicked: Notifications.dismiss(modelData)
                        }
                    }
                }

                MEmptyState {
                    visible: Notifications.list.length === 0
                    anchors.fill: parent
                    iconName: "preferences-system-notifications-symbolic"
                    titleKey: "notifications.empty"
                }
            }
        }
    }
}
