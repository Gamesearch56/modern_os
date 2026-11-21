import QtQuick
import QtQuick.Window
import "../../Commons"
import "../../Widgets"

// One menu of editor commands from actions.js. Under its button by
// default; openAt() puts it at the pointer for the right-click menu.
MPopup {
    id: root

    property var actions: null
    property var items: []
    property bool atPointer: false
    property real pointX: 0
    property real pointY: 0

    readonly property Item _window: Window.window ? Window.window.contentItem : null

    width: Tokens.spacing.xxl * 10
    height: column.implicitHeight + Tokens.spacing.md * 2
    autoPlace: !root.atPointer
    dismissAnywhere: root.atPointer

    function openAt(px: real, py: real) {
        root.pointX = px;
        root.pointY = py;
        root.atPointer = true;
        root.open = true;
    }

    function _fit(raw: real, size: real, room: real): real {
        const pad = Tokens.spacing.md;
        return Math.max(pad, Math.min(raw, room - size - pad));
    }

    Binding {
        target: root
        property: "x"
        when: root.atPointer
        value: root._fit(root.pointX, root.width, root._window ? root._window.width : 0)
    }
    Binding {
        target: root
        property: "y"
        when: root.atPointer
        value: root._fit(root.pointY, root.height, root._window ? root._window.height : 0)
    }

    Column {
        id: column
        width: parent ? parent.width : 0
        spacing: Tokens.spacing.xxs

        Repeater {
            model: root.items
            delegate: Column {
                id: entry
                required property var modelData
                required property int index
                width: column.width
                spacing: Tokens.spacing.xxs

                MDivider {
                    visible: entry.modelData.divider === true && entry.index > 0
                    width: parent.width
                    height: Tokens.stroke.hairline
                }

                MListItem {
                    width: parent.width
                    height: implicitHeight
                    compact: true
                    iconName: entry.modelData.icon || ""
                    titleKey: entry.modelData.key
                    destructive: entry.modelData.danger === true
                    enabled: root.actions ? root.actions.enabled(entry.modelData.id) : false
                    selected: !entry.modelData.icon && root.actions ? root.actions.checked(entry.modelData.id) : false
                    onClicked: {
                        root.open = false;
                        root.actions.run(entry.modelData.id);
                    }

                    MSwitch {
                        visible: entry.modelData.toggle === true && (entry.modelData.icon || "").length > 0
                        compact: true
                        nameKey: entry.modelData.key
                        checked: root.actions ? root.actions.checked(entry.modelData.id) : false
                        onToggled: {
                            root.open = false;
                            root.actions.run(entry.modelData.id);
                        }
                    }

                    MText {
                        visible: entry.modelData.toggle !== true && text.length > 0
                        value: root.actions ? root.actions.keyLabel(entry.modelData.id) : ""
                        styleName: "labelMedium"
                        color: Colors.color.onSurfaceVariant
                    }
                }
            }
        }
    }
}
