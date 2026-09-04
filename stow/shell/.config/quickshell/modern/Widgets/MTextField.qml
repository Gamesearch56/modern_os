// Single-line filled field with a primary focus ring.
import QtQuick
import "../Commons"

Item {
    id: root

    property alias text: input.text
    readonly property alias focused: input.activeFocus
    property alias editor: input
    property string placeholderKey: ""
    property string iconName: ""
    property int echoMode: TextInput.Normal
    property bool enabled: true
    property int maximumLength: 32767
    property bool escapeCloses: false
    property bool captureArrows: false
    property bool holdFocus: false
    property bool _pointer: false

    readonly property bool _a11yFocus: input.activeFocus && (root.holdFocus || !root._pointer)

    signal accepted()
    signal textEdited()
    signal editingFinished()
    signal escaped()
    signal upPressed()
    signal downPressed()

    implicitWidth: Tokens.spacing.xxl * 8
    implicitHeight: Tokens.spacing.xxl + Tokens.spacing.xs
    opacity: root.enabled ? 1 : 0.38
    activeFocusOnTab: root.enabled
    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholderKey.length > 0 ? I18n.t(root.placeholderKey) : ""
    Accessible.editable: true

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.IBeamCursor
    }

    onActiveFocusChanged: {
        if (root.activeFocus && !input.activeFocus)
            input.forceActiveFocus();
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        grabPermissions: PointerHandler.TakeOverForbidden
        onPressedChanged: {
            if (pressed)
                root._pointer = true;
        }
    }

    Connections {
        target: input
        function onActiveFocusChanged() {
            if (!input.activeFocus)
                root._pointer = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surfaceContainerHighest
        border.color: root._a11yFocus ? Colors.color.primary : Colors.color.outline
        border.width: root._a11yFocus ? Tokens.stroke.focus : Tokens.stroke.hairline

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    MIcon {
        visible: root.iconName.length > 0
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        name: root.iconName
        size: Tokens.icon.md
        color: Colors.color.onSurfaceVariant
        tint: true
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.iconName.length > 0 ? Tokens.spacing.xxl + Tokens.spacing.xs : Tokens.spacing.md
        anchors.rightMargin: Tokens.spacing.md
        verticalAlignment: TextInput.AlignVCenter
        color: Colors.color.onSurface
        selectionColor: Colors.color.primary
        selectedTextColor: Colors.color.onPrimary
        font.family: Typography.family.ui
        font.pixelSize: Typography.style("bodyLarge").pixelSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: TextInput.QtRendering
        echoMode: root.echoMode
        enabled: root.enabled
        maximumLength: root.maximumLength
        activeFocusOnTab: false
        activeFocusOnPress: true
        selectByMouse: true
        clip: true
        onAccepted: root.accepted()
        onTextChanged: root.textEdited()
        onEditingFinished: root.editingFinished()
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.escaped();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down) {
                root.downPressed();
                event.accepted = root.captureArrows || root._arrowMove(0, 1);
            } else if (event.key === Qt.Key_Up) {
                root.upPressed();
                event.accepted = root.captureArrows || root._arrowMove(0, -1);
            }
        }
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: input
        key: root.placeholderKey
        styleName: "bodyLarge"
        color: Colors.color.onSurfaceVariant
    }

    function _arrowMove(dx: int, dy: int): bool {
        let p = root.parent;
        while (p) {
            if (typeof p.arrowMove === "function")
                return p.arrowMove(dx, dy);
            p = p.parent;
        }
        return false;
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function focusToType() {
        root._pointer = true;
        input.forceActiveFocus();
    }
}
