//@ pragma IconTheme Papirus-Dark
// Entry point for the modern Quickshell session. Modules are composed
// here; none of them import each other.
import Quickshell
import QtQuick
import Quickshell.Io
import "Commons"
import "Services"
import "Modules/Bar" as Bar
import "Modules/Dock" as DockMod
import "Modules/Launcher" as LauncherMod
import "Modules/PowerMenu" as PowerMenuMod
import "Modules/Cheatsheet" as CheatsheetMod
import "Modules/Onboarding" as Onboarding
import "Modules/Overview" as OverviewMod
import "Modules/Notifications" as NotificationsMod
import "Modules/Settings" as SettingsMod
import "Modules/Store" as StoreMod
import "Modules/Plugins" as PluginsMod
import "Modules/Session" as SessionMod
import "Modules/Wallpaper" as WallpaperMod
import "Modules/Screenshot" as ScreenshotMod
import "Modules/FilePreview" as FilePreviewMod
import "Modules/Files" as FilesMod
import "Modules/BugReport" as BugReportMod

ShellRoot {
    Bar.Module {}
    DockMod.Module {}
    LauncherMod.Module {}
    PowerMenuMod.Module {}
    CheatsheetMod.Module {}
    Onboarding.Module {}
    OverviewMod.Module {}
    NotificationsMod.Module {}
    SettingsMod.Module {}
    StoreMod.Module {}
    PluginsMod.Module {}
    SessionMod.Module {}
    WallpaperMod.Module {}
    ScreenshotMod.Module {}
    FilePreviewMod.Module {}
    FilesMod.Module {}
    BugReportMod.Module {}

    Shortcut {
        sequence: "Escape"
        enabled: Popups.active !== null
        context: Qt.ApplicationShortcut
        onActivated: Popups.dismiss()
    }

    Connections {
        target: Popups
        function onExclusive(keeper) {
            if (!keeper)
                return;
            Launcher.hide();
            Notifications.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            FilePreview.hide();
        }
    }

    Connections {
        target: Launcher
        function onOpenChanged() {
            if (!Launcher.open)
                return;
            Popups.dismiss();
            Notifications.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            FilePreview.hide();
            Ai.hide();
        }
    }

    Connections {
        target: Notifications
        function onPanelOpenChanged() {
            if (!Notifications.panelOpen)
                return;
            Popups.dismiss();
            Launcher.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            FilePreview.hide();
            Ai.hide();
        }
    }

    Connections {
        target: PowerMenu
        function onOpenChanged() {
            if (!PowerMenu.open)
                return;
            Popups.dismiss();
            Launcher.hide();
            Notifications.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            FilePreview.hide();
            Ai.hide();
        }
    }

    Connections {
        target: Wallpaper
        function onPickerOpenChanged() {
            if (!Wallpaper.pickerOpen)
                return;
            Popups.dismiss();
            Launcher.hide();
            Notifications.hide();
            PowerMenu.hide();
            Cheatsheet.hide();
            FilePreview.hide();
            Ai.hide();
        }
    }

    Connections {
        target: Cheatsheet
        function onOpenChanged() {
            if (!Cheatsheet.open)
                return;
            Popups.dismiss();
            Launcher.hide();
            Notifications.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            FilePreview.hide();
            Ai.hide();
        }
    }

    Connections {
        target: FilePreview
        function onOpenChanged() {
            if (!FilePreview.open)
                return;
            Popups.dismiss();
            Launcher.hide();
            Notifications.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            Ai.hide();
        }
    }

    Connections {
        target: Ai
        function onPanelOpenChanged() {
            if (!Ai.panelOpen)
                return;
            Launcher.hide();
            Notifications.hide();
            PowerMenu.hide();
            Wallpaper.hide();
            Cheatsheet.hide();
            FilePreview.hide();
            Taskbar.hide();
        }
    }

    IpcHandler {
        target: "shell"
        function reload() { Quickshell.reload(true); }
        // SUPER+Q is a Hyprland bind (it never reaches QML Shortcuts).
        // Return "true" when a layer HUD/popup/control panel ate the close.
        function dismiss(): string {
            let closed = false;
            if (Screenshot.hudOpen) {
                Screenshot.cancelHud();
                closed = true;
            }
            // A recording is not a dialog. Super+Q keeps closing the
            // focused window, and the other binds keep working.
            if (Popups.dismiss())
                closed = true;
            if (Plugins.open) {
                Plugins.hide();
                closed = true;
            }
            if (Notifications.panelOpen) {
                Notifications.hide();
                closed = true;
            }
            if (Taskbar.open) {
                Taskbar.hide();
                closed = true;
            }
            if (Wallpaper.providerOpen) {
                Wallpaper.closeProvider();
                closed = true;
            }
            if (FilePreview.open) {
                FilePreview.hide();
                closed = true;
            }
            if (Ai.panelOpen) {
                Ai.hide();
                closed = true;
            }
            if (Alarm.dialogOpen) {
                Alarm.dialogOpen = false;
                closed = true;
            }
            return closed ? "true" : "false";
        }
        function closeFocused(): string {
            return Hypr.closeFocused();
        }
    }

    // Quickshell draws its own "reloaded" popup after this signal, and that
    // bar stays up. The update notice is the confirmation the session shows.
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
    }

    Component.onCompleted: {
        Logger.info("shell", "session started");
        Brightness.refresh();
        UpdateBoot.arm();
    }
}
