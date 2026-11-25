import QtQuick
import "../../Commons"
import "../../Widgets"
import "links.js" as Links

// The open document, rendered from its markdown. Text can be selected
// and copied (commands in the troubleshooting chapters); the column is
// capped at a reading width so long lines stay easy to follow. Tab walks
// the links without a mouse and Ctrl + plus/minus scales the text.
FocusScope {
    id: root

    property var doc: null
    property bool failed: false
    property int zoom: 100
    readonly property int zoomMin: 50
    readonly property int zoomMax: 300
    readonly property int zoomStep: 10
    property var _stops: null
    property int _stop: -1
    readonly property var _style: Typography.style("bodyLarge")
    readonly property real _scale: root.zoom / 100
    readonly property real _step: root._style.lineHeight * 3
    // {{measure:N}} is N % of the text column, for pictures sized in percent.
    readonly property real _measure: Math.min(Tokens.window.manualMeasure, flick.width - Tokens.spacing.md * 2)
    readonly property var _fills: ({
        heading: String(Colors.color.onSurface),
        muted: String(Colors.color.onSurfaceVariant),
        link: String(Colors.color.primary),
        codeBg: String(Colors.color.surfaceContainerHighest),
        rule: String(Colors.color.outlineVariant),
        mono: Typography.family.monospace,
        h1: Math.round(Typography.style("headlineMedium").pixelSize * root._scale),
        h2: Math.round(Typography.style("titleLarge").pixelSize * root._scale),
        h3: Math.round(Typography.style("titleMedium").pixelSize * root._scale),
        h4: Math.round(Typography.style("titleSmall").pixelSize * root._scale),
        codeSize: Math.round(Typography.style("bodyMedium").pixelSize * root._scale),
        gap: Math.round(Tokens.spacing.md),
        tight: Math.round(Tokens.spacing.xs),
        headGap: Math.round(Tokens.spacing.xl),
        pad: Math.round(Tokens.spacing.sm)
    })
    readonly property string _html: root.doc
        ? String(root.doc.html || "").replace(/\{\{(\w+)(?::(\d+))?\}\}/g, (m, k, pct) => pct
            ? String(Math.round(root._measure * Number(pct) / 100))
            : String(root._fills[k] ?? ""))
        : ""

    signal linkActivated(string link)
    signal navRequested()

    function _maxY(): real {
        return Math.max(0, flick.contentHeight - flick.height);
    }

    // A layout pass (a new chapter, or a recolor) can leave the scroll
    // past the text. That is the blank page: the text is above the view.
    function _clampY() {
        const maxY = root._maxY();
        if (flick.contentY < 0 || flick.contentY > maxY)
            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY));
    }

    function _scrollBy(dy: real) {
        flick.contentY = Math.max(0, Math.min(root._maxY(), flick.contentY + dy));
    }

    function zoomBy(steps: int) {
        root.zoom = Math.max(root.zoomMin, Math.min(root.zoomMax, root.zoom + steps * root.zoomStep));
    }

    // While a new page is laid out, ignore the flick still running from
    // the previous one. Interactive scrolling comes back on the next turn.
    property bool _reset: false

    function _showTop() {
        root._reset = true;
        flick.contentY = 0;
        Qt.callLater(() => {
            flick.contentY = 0;
            root._reset = false;
        });
    }

    // Past the last link Tab is left unhandled, so focus moves on.
    function _hop(delta: int): bool {
        if (root._stops === null)
            root._stops = Links.stops(root._html, body.getText(0, body.length));
        const next = root._stop + delta;
        if (next < 0 || next >= root._stops.length) {
            root._stop = -1;
            body.deselect();
            return false;
        }
        root._stop = next;
        const s = root._stops[next];
        body.select(s.start, s.end);
        const r = body.positionToRectangle(s.start);
        const top = body.y + r.y - root._step;
        if (top < flick.contentY || body.y + r.y + r.height > flick.contentY + flick.height)
            flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, top));
        return true;
    }

    onDocChanged: {
        body.deselect();
        root._showTop();
        root._stops = null;
        root._stop = -1;
    }
    on_HtmlChanged: root._stops = null
    activeFocusOnTab: true
    onActiveFocusChanged: if (!activeFocus) root._stop = -1
    Accessible.role: Accessible.Document
    Accessible.name: root.doc ? root.doc.title : ""
    Accessible.description: root._stop >= 0 ? I18n.t("manual.link", { name: body.selectedText }) : ""

    Keys.onPressed: (event) => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Tab && !ctrl) {
            if (!root._hop(1))
                return;
        } else if (event.key === Qt.Key_Backtab && !ctrl) {
            if (!root._hop(-1))
                return;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root._stop >= 0) {
            const href = root._stops[root._stop].href;
            root._stop = -1;
            body.deselect();
            root.linkActivated(href);
        } else if (ctrl && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)) {
            root.zoomBy(1);
        } else if (ctrl && event.key === Qt.Key_Minus) {
            root.zoomBy(-1);
        } else if (ctrl && event.key === Qt.Key_0) {
            root.zoom = 100;
        } else if (event.matches(StandardKey.Copy)) {
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
        contentHeight: body.y + body.height + Tokens.spacing.xl
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root._reset
        onContentHeightChanged: root._reset ? contentY = 0 : root._clampY()
        onHeightChanged: root._clampY()
        onMovementEnded: root._clampY()
        onFlickEnded: root._clampY()

        TextEdit {
            id: body
            x: Math.max(Tokens.spacing.md, (flick.width - width) / 2)
            y: Tokens.spacing.xl
            width: root._measure
            // As tall as the text, so the page cannot scroll into the
            // empty area under a shorter control (report 54).
            height: contentHeight
            text: root._html
            textFormat: TextEdit.RichText
            readOnly: true
            selectByMouse: true
            activeFocusOnPress: false
            wrapMode: TextEdit.Wrap
            color: Colors.color.onSurface
            // Table cells read the palette, not this color. Left alone they
            // stay black on the dark page while the grid stays visible.
            palette.text: Colors.color.onSurface
            palette.windowText: Colors.color.onSurface
            selectionColor: Colors.color.primaryContainer
            selectedTextColor: Colors.color.onPrimaryContainer
            font.family: Typography.family.document
            font.pixelSize: Math.round(root._style.pixelSize * root._scale)
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

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => root.zoomBy(event.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
