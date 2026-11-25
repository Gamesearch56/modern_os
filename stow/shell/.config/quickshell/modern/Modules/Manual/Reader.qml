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
    readonly property real _inset: Tokens.spacing.lg
    readonly property real _measure: Math.min(Tokens.window.manualMeasure, flick.width - root._inset * 2)
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
        // One rhythm for a long read. block is the pause between
        // paragraphs, item the pause inside a list or a table cell,
        // headTop the break before a new section.
        gap: Math.round(Tokens.spacing.lg),
        tight: Math.round(Tokens.spacing.sm),
        headGap: Math.round(Tokens.spacing.xxl),
        pad: Math.round(Tokens.spacing.md)
    })
    readonly property string _html: root.doc
        ? String(root.doc.html || "").replace(/\{\{(\w+)(?::(\d+))?\}\}/g, (m, k, pct) => pct
            ? String(Math.round(root._measure * Number(pct) / 100))
            : String(root._fills[k] ?? ""))
        : ""
    // Empty while a chapter is being swapped, so the old text item is
    // gone before the new one is built. See _reopen.
    property string _shown: ""
    property bool _opening: false
    readonly property var body: page.item

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

    function _pinTop() {
        flick.cancelFlick();
        flick.contentY = 0;
    }

    // The scrolled text item keeps its clip. Drop it first, with the
    // flick already at the top, and build the next chapter on the next
    // turn so the new item has never been scrolled.
    function _reopen() {
        root._stops = null;
        root._stop = -1;
        root._opening = true;
        root._pinTop();
        root._shown = "";
        Qt.callLater(root._present);
    }

    function _present() {
        root._pinTop();
        root._shown = root.doc ? String(root.doc.path || "chapter") : "";
        if (!root._shown.length)
            root._opening = false;
    }

    // Past the last link Tab is left unhandled, so focus moves on.
    function _hop(delta: int): bool {
        if (!body)
            return false;
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
        const top = page.y + r.y - root._step;
        if (top < flick.contentY || page.y + r.y + r.height > flick.contentY + flick.height)
            flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, top));
        return true;
    }

    onDocChanged: root._reopen()
    activeFocusOnTab: true
    onActiveFocusChanged: if (!activeFocus) root._stop = -1
    Accessible.role: Accessible.Document
    Accessible.name: root.doc ? root.doc.title : ""
    Accessible.description: root._stop >= 0 && body ? I18n.t("manual.link", { name: body.selectedText }) : ""

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
            if (body)
                body.deselect();
            root.linkActivated(href);
        } else if (ctrl && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)) {
            root.zoomBy(1);
        } else if (ctrl && event.key === Qt.Key_Minus) {
            root.zoomBy(-1);
        } else if (ctrl && event.key === Qt.Key_0) {
            root.zoom = 100;
        } else if (event.matches(StandardKey.Copy)) {
            if (body)
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
        contentHeight: Math.max(height, page.y + page.height + Tokens.spacing.xl)
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: {
            if (root._opening && contentY !== 0)
                Qt.callLater(root._pinTop);
        }
        onContentHeightChanged: {
            if (root._opening) {
                root._pinTop();
                settle.restart();
            } else {
                root._clampY();
            }
        }
        onHeightChanged: if (!root._opening) root._clampY()
        onMovementEnded: if (!root._opening) root._clampY()
        onFlickEnded: if (!root._opening) root._clampY()

        Timer {
            id: settle
            interval: Motion.durationMedium
            onTriggered: {
                if (root._opening)
                    root._pinTop();
                root._opening = false;
            }
        }

        Loader {
            id: page
            x: Math.max(root._inset, (flick.width - width) / 2)
            y: Tokens.spacing.xl
            width: root._measure
            // A path, not a type: this directory has no qmldir, and a new
            // file is not registered as a type. Clearing the source
            // destroys the scrolled text before the next chapter is built.
            source: root._shown.length ? "ReaderBody.qml" : ""
            onLoaded: {
                item.text = Qt.binding(() => root._html);
                item.textScale = Qt.binding(() => root._scale);
                item.linkActivated.connect((link) => root.linkActivated(link));
                item.activate.connect(() => root.forceActiveFocus());
                settle.restart();
            }
        }

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => root.zoomBy(event.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
