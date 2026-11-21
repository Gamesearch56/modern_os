import QtQuick
import "../../Commons"
import "../../Services"
import "actions.js" as ActionList

// What each command in actions.js does, and when it can. The toolbar, the
// menu and the keys call run(id); none of them reach into the stage.
QtObject {
    id: root

    property var stage: null
    property var window: null
    property var dialog: null

    readonly property bool _shown: !ViewerDoc.empty && !!root.stage && root.stage.ready
    readonly property real _panStep: Tokens.spacing.xxl * 2

    function def(id: string): var {
        return ActionList.byId(id);
    }

    function menuItems(): var {
        return ActionList.menuItems();
    }

    function enabled(id: string): bool {
        switch (id) {
        case "open":
        case "newWindow":
        case "close":
        case "fullscreen":
        case "leave":
        case "info":
            return true;
        case "next":
        case "previous":
        case "first":
        case "last":
        case "slideshow":
            return ViewerDoc.count > 1;
        case "saveRotation":
            return ViewerDoc.rotation !== 0 && ViewerDoc.info.rotatable === true
                && ViewerDoc.info.writable === true && !ViewerDoc.busy;
        case "trash":
            return !ViewerDoc.empty && !ViewerDoc.busy;
        case "pause":
            return root._shown && ViewerDoc.info.animated === true;
        case "reveal":
        case "copyPath":
        case "remove":
            return !ViewerDoc.empty;
        default:
            return root._shown;
        }
    }

    function checked(id: string): bool {
        if (id === "info")
            return ViewerPrefs.info;
        if (id === "slideshow")
            return ViewerDoc.slideshow;
        if (id === "pause")
            return ViewerDoc.paused;
        if (id === "fullscreen")
            return !!root.window && root.window.fullscreen;
        return false;
    }

    function run(id: string) {
        if (!root.enabled(id))
            return;
        const s = root.stage;
        switch (id) {
        case "open": root.window.module.choose(); break;
        case "newWindow": ViewerDoc.openWindow(); break;
        case "reveal": ViewerDoc.reveal(); break;
        case "copy": ViewerDoc.copyImage(); break;
        case "copyPath": ViewerDoc.copyPath(); break;
        case "saveRotation": ViewerDoc.saveRotation(null); break;
        case "remove": ViewerDoc.remove(); break;
        case "trash": root.dialog.ask("trash", { name: ViewerDoc.name }); break;
        case "close": root.window.module.quit(); break;
        case "next": ViewerDoc.next(); break;
        case "previous": ViewerDoc.previous(); break;
        case "first": ViewerDoc.first(); break;
        case "last": ViewerDoc.last(); break;
        case "slideshow": ViewerDoc.setSlideshow(!ViewerDoc.slideshow); break;
        case "zoomIn": s.zoomIn(); break;
        case "zoomOut": s.zoomOut(); break;
        case "fit": s.fit(); break;
        case "actual": s.actual(); break;
        case "scaling": ViewerPrefs.nextScaling(); s.fit(); break;
        case "rotateRight": ViewerDoc.rotate(1); break;
        case "rotateLeft": ViewerDoc.rotate(-1); break;
        case "pause": ViewerDoc.paused = !ViewerDoc.paused; break;
        case "info": ViewerPrefs.setInfo(!ViewerPrefs.info); break;
        case "fullscreen": ViewerDoc.toggleFullscreen(); break;
        case "leave":
            if (root.window.fullscreen)
                ViewerDoc.toggleFullscreen();
            else if (ViewerDoc.slideshow)
                ViewerDoc.setSlideshow(false);
            break;
        case "panLeft": s.pan(-root._panStep, 0); break;
        case "panRight": s.pan(root._panStep, 0); break;
        case "panUp": s.pan(0, -root._panStep); break;
        case "panDown": s.pan(0, root._panStep); break;
        default: break;
        }
        if (id !== "trash" && id !== "open" && s)
            s.forceActiveFocus();
    }

    function keyLabel(id: string): string {
        const a = ActionList.byId(id);
        return a && a.keys.length ? KeyLabel.of(a.keys[0]) : "";
    }
}
