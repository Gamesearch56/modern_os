import QtQuick
import "../../Commons"
import "../../Widgets"

// The open document, rendered from its markdown. Text can be selected
// and copied (commands in the troubleshooting chapters); the column is
// capped at a reading width so long lines stay easy to follow.
FocusScope {
    id: root

    property var doc: null
    property bool failed: false
    readonly property var _style: Typography.style("bodyLarge")
    readonly property real _step: root._style.lineHeight * 3
    readonly property var _fills: ({
        heading: String(Colors.color.onSurface),
        muted: String(Colors.color.onSurfaceVariant),
        link: String(Colors.color.primary),
        codeBg: String(Colors.color.surfaceContainerHighest),
        rule: String(Colors.color.outlineVariant),
        mono: Typography.family.monospace,
        h1: Typography.style("headlineMedium").pixelSize,
        h2: Typography.style("titleLarge").pixelSize,
        h3: Typography.style("titleMedium").pixelSize,
        h4: Typography.style("titleSmall").pixelSize,
        codeSize: Typography.style("bodyMedium").pixelSize,
        gap: Math.round(Tokens.spacing.md),
        tight: Math.round(Tokens.spacing.xs),
        headGap: Math.round(Tokens.spacing.xl),
        pad: Math.round(Tokens.spacing.sm),
        leading: Math.round(100 * root._style.lineHeight / root._style.pixelSize)
    })
    readonly property string _html: root.doc
        ? String(root.doc.html || "").replace(/\{\{(\w+)\}\}/g, (m, k) => String(root._fills[k] ?? ""))
        : ""

    signal linkActivated(string link)
    signal navRequested()

    function _scrollBy(dy: real) {
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy));
    }

    onDocChanged: flick.contentY = 0
    activeFocusOnTab: true

    Keys.onPressed: (event) => {
        if (event.matches(StandardKey.Copy)) {
            body.copy();
        } else if (event.key === Qt.Key_Down) {
            root._scrollBy(root._step);
        } else if (event.key === Qt.Key_Up) {
            root._scrollBy(-root._step);
        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) {
            root._scrollBy(flick.height - root._step);
        } else if (event.key === Qt.Key_PageUp) {
            root._scrollBy(root._step - flick.height);
        } else if (event.key === Qt.Key_Home) {
            flick.contentY = 0;
        } else if (event.key === Qt.Key_End) {
            root._scrollBy(flick.contentHeight);
        } else if (event.key === Qt.Key_Left) {
            root.navRequested();
        } else {
            return;
        }
        event.accepted = true;
    }

    MEmptyState {
        anchors.centerIn: parent
        visible: !root.doc && root.failed
        iconName: "help-contents"
        titleKey: "manual.unavailable"
        hintKey: "manual.unavailableHint"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        visible: !!root.doc
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + Tokens.spacing.xl * 2
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: body
            x: Math.max(Tokens.spacing.md, (flick.width - width) / 2)
            y: Tokens.spacing.xl
            width: Math.min(Tokens.window.manualMeasure, flick.width - Tokens.spacing.md * 2)
            text: root._html
            textFormat: TextEdit.RichText
            readOnly: true
            selectByMouse: true
            activeFocusOnPress: false
            wrapMode: TextEdit.Wrap
            color: Colors.color.onSurface
            selectionColor: Colors.color.primaryContainer
            selectedTextColor: Colors.color.onPrimaryContainer
            font.family: Typography.family.document
            font.pixelSize: root._style.pixelSize
            font.letterSpacing: root._style.letterSpacing
            palette.link: Colors.color.primary
            onLinkActivated: (link) => root.linkActivated(link)

            HoverHandler {
                cursorShape: body.hoveredLink.length ? Qt.PointingHandCursor : Qt.IBeamCursor
            }
            TapHandler {
                onTapped: root.forceActiveFocus()
            }
        }
    }
}
