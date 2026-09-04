import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    id: root

    property bool _restoreSettings: false
    property string _restoreSection: "design"
    property string _restoreSub: ""
    property bool _reopenAfterSettings: false
    property string _pendingChooser: ""

    Connections {
        target: Wallpaper
        function onFetched(path) {
            Notifications.toast(I18n.t("wallpaper.fetched"), I18n.t("wallpaper.fetchedHint"), path);
        }
        function onFetchFailed() {
            Notifications.toast(I18n.t("wallpaper.fetchFailed"), "");
        }
        function onOpenedInBrowser() {
            Notifications.toast(I18n.t("wallpaper.providerBrowser"), I18n.t("wallpaper.providerBrowserHint"));
        }
        function onChooserStarted(kind) {
            root._pendingChooser = String(kind || "");
            if (Settings.open) {
                root._restoreSettings = true;
                root._restoreSection = Settings.sectionId;
                root._restoreSub = Settings.subsectionId;
                Settings.close();
                startChooser.interval = Motion.mediumMs;
            } else {
                root._restoreSettings = false;
                startChooser.interval = Motion.shortMs;
            }
            startChooser.restart();
        }
        function onChooserFinished(reopen) {
            const restore = root._restoreSettings;
            const section = root._restoreSection;
            const sub = root._restoreSub;
            root._restoreSettings = false;
            root._reopenAfterSettings = !!reopen;
            if (restore) {
                Settings.openAt(section, sub);
                afterSettings.restart();
                return;
            }
            if (reopen)
                Wallpaper.setPickerOpen(true);
        }
    }

    Timer {
        id: startChooser
        interval: Motion.shortMs
        repeat: false
        onTriggered: {
            const kind = root._pendingChooser;
            root._pendingChooser = "";
            if (kind.length)
                Wallpaper.beginChooser(kind);
        }
    }

    Timer {
        id: afterSettings
        interval: Motion.mediumMs
        repeat: false
        onTriggered: {
            Hypr.raiseDesktop("modern.settings");
            if (root._reopenAfterSettings)
                reopenPicker.restart();
            else
                root._reopenAfterSettings = false;
        }
    }

    Timer {
        id: reopenPicker
        interval: Motion.shortMs
        repeat: false
        onTriggered: {
            Wallpaper.setPickerOpen(true);
            root._reopenAfterSettings = false;
        }
    }

    LazyLoader {
        active: Wallpaper.pickerOpen

        FloatingWindow {
            id: win
            visible: Wallpaper.pickerOpen
            title: "modern.wallpaper"
            color: "transparent"
            implicitWidth: Tokens.window.settingsWidth
            implicitHeight: Tokens.window.settingsHeight

            onVisibleChanged: {
                if (visible)
                    win.requestActivate();
                else
                    Wallpaper.hide();
            }

            Overlay {
                id: overlay
                anchors.fill: parent
                onClosed: Wallpaper.hide()
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (overlay.confirming)
                        overlay.cancelRemove();
                    else
                        Wallpaper.hide();
                }
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Left"
                onActivated: overlay.moveBy(-1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Right"
                onActivated: overlay.moveBy(1)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Up"
                onActivated: overlay.moveBy(-overlay.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Down"
                onActivated: overlay.moveBy(overlay.columns)
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Return"
                onActivated: overlay.activate()
            }
            Shortcut {
                enabled: Wallpaper.images.length > 0 && !overlay.confirming
                sequence: "Enter"
                onActivated: overlay.activate()
            }
        }
    }
}
