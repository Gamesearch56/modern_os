// Single-line filled field with a primary focus ring.
import QtQuick
import Quickshell
import "../Commons"

Item {
    id: root

    property alias text: input.text
    readonly property alias focused: input.activeFocus
    property alias editor: input
    property string placeholderKey: ""
    property string iconName: ""
    property string trailingIcon: ""
    property int echoMode: TextInput.Normal
    property bool enabled: true
    property int maximumLength: 32767
    property bool escapeCloses: false
    property bool captureArrows: false
    property bool captureReturn: false
    property bool captureEscape: false
    property bool holdFocus: false
    property bool selectAllOnPress: false
    // The location field: Ctrl+C copies a shell-safe path, not the raw text.
    property bool terminalCopy: false
    property bool selectOnFocus: false
    property bool _pointer: false
    property bool capsOn: false

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
    activeFocusOnTab: true
    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholderKey.length > 0 ? I18n.t(root.placeholderKey) : ""
    Accessible.editable: true

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.IBeamCursor
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
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
            if (!input.activeFocus) {
                root._pointer = false;
                return;
            }
            if (root.selectOnFocus)
                input.selectAll();
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

    MIcon {
        visible: root.trailingIcon.length > 0
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        name: root.trailingIcon
        size: Tokens.icon.md
        color: Colors.color.onSurfaceVariant
        tint: true
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.iconName.length > 0 ? Tokens.spacing.xxl + Tokens.spacing.xs : Tokens.spacing.md
        anchors.rightMargin: root.trailingIcon.length > 0 ? Tokens.spacing.xxl + Tokens.spacing.xs : Tokens.spacing.md
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
        Keys.onShortcutOverride: (event) => {
            const ret = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
            const arrow = event.key === Qt.Key_Up || event.key === Qt.Key_Down;
            const esc = root.captureEscape && event.key === Qt.Key_Escape;
            if ((root.captureReturn && ret) || (root.captureArrows && arrow) || esc || root._pathCopy(event))
                event.accepted = true;
        }
        Keys.onPressed: (event) => {
            if (root._pathCopy(event)) {
                Quickshell.clipboardText = root._shell(root._chunk());
                event.accepted = true;
                return;
            }
            root._noteCaps(event);
            if (event.key === Qt.Key_Escape) {
                root.escaped();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = root._arrowMove(0, event.key === Qt.Key_Backtab ? -1 : 1);
                return;
            }
            const editing = input.selectionStart !== input.selectionEnd;
            if (!editing && event.key === Qt.Key_Left && input.cursorPosition === 0) {
                event.accepted = root._arrowMove(-1, 0);
                return;
            }
            if (!editing && event.key === Qt.Key_Right && input.cursorPosition === input.length) {
                event.accepted = root._arrowMove(1, 0);
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

    MouseArea {
        anchors.fill: parent
        enabled: root.selectAllOnPress
        z: 2
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onPressed: {
            input.forceActiveFocus();
            input.selectAll();
        }
        HoverHandler {
            enabled: root.selectAllOnPress
            cursorShape: Qt.IBeamCursor
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: input
        key: root.placeholderKey
        styleName: "bodyLarge"
        color: Colors.color.onSurfaceVariant
    }

    function _pathCopy(event): bool {
        if (!root.terminalCopy || !event || event.key !== Qt.Key_C)
            return false;
        const mods = event.modifiers;
        if ((mods & Qt.ControlModifier) === 0 || (mods & Qt.AltModifier) || (mods & Qt.MetaModifier))
            return false;
        return String(input.text || "").charAt(0) === "/";
    }

    function _chunk(): string {
        const picked = String(input.selectedText || "");
        return picked.length ? picked : String(input.text || "");
    }

    // One cd argument: spaces and other shell metacharacters get a backslash.
    function _shell(path: string): string {
        const meta = " \t\n\\'\"`$&|;<>()*?[]{}!#~";
        let out = "";
        for (let i = 0; i < path.length; i++) {
            const ch = path.charAt(i);
            out += meta.indexOf(ch) >= 0 ? ("\\" + ch) : ch;
        }
        return out;
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

    function _noteCaps(event: var) {
        if (event.key === Qt.Key_CapsLock) {
            root.capsOn = !root.capsOn;
            return;
        }
        const t = event.text || "";
        if (t.length !== 1)
            return;
        const lower = t.toLowerCase();
        const upper = t.toUpperCase();
        if (lower === upper)
            return;
        const shift = !!(event.modifiers & Qt.ShiftModifier);
        root.capsOn = (t === upper) !== shift;
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
