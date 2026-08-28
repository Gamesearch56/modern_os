//@ pragma IconTheme Papirus-Dark
// Entry point for the modern Quickshell session. Modules are composed
// here; none of them import each other.
import Quickshell
import QtQuick
import Quickshell.Io
import "Commons"
import "Services"
import "Modules/Bar" as Bar
import "Modules/Launcher" as LauncherMod
import "Modules/PowerMenu" as PowerMenuMod
import "Modules/Cheatsheet" as CheatsheetMod
import "Modules/Onboarding" as Onboarding
import "Modules/Overview" as OverviewMod
import "Modules/Notifications" as NotificationsMod
import "Modules/Settings" as SettingsMod
import "Modules/Plugins" as PluginsMod
import "Modules/Session" as SessionMod
import "Modules/Wallpaper" as WallpaperMod
import "Modules/Screenshot" as ScreenshotMod

ShellRoot {
    Bar.Module {}
    LauncherMod.Module {}
    PowerMenuMod.Module {}
    CheatsheetMod.Module {}
    Onboarding.Module {}
    OverviewMod.Module {}
    NotificationsMod.Module {}
    SettingsMod.Module {}
    PluginsMod.Module {}
    SessionMod.Module {}
    WallpaperMod.Module {}
    ScreenshotMod.Module {}

    IpcHandler {
        target: "shell"
        function reload() { Quickshell.reload(true); }
        // SUPER+Q is a Hyprland bind (it never reaches QML Shortcuts).
        // Return "true" when an overlay ate the close so killactive is skipped.
        function dismiss(): string {
            let closed = false;
            if (Screenshot.hudOpen) {
                Screenshot.cancelHud();
                closed = true;
            }
            if (Settings.open) {
                Settings.close();
                closed = true;
            }
            if (Wallpaper.pickerOpen) {
                Wallpaper.setPickerOpen(false);
                closed = true;
            }
            if (Plugins.open) {
                Plugins.hide();
                closed = true;
            }
            if (Cheatsheet.open) {
                Cheatsheet.hide();
                closed = true;
            }
            if (PowerMenu.open) {
                PowerMenu.hide();
                closed = true;
            }
            if (Overview.open) {
                Overview.hide();
                closed = true;
            }
            if (Launcher.open) {
                Launcher.hide();
                closed = true;
            }
            if (Notifications.panelOpen) {
                Notifications.hide();
                closed = true;
            }
            return closed ? "true" : "false";
        }
    }

    Component.onCompleted: Logger.info("shell", "session started")
}
