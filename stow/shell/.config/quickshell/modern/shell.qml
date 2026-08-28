// Entry point for the modern Quickshell session. Modules are composed
// here; none of them import each other.
import Quickshell
import QtQuick
import Quickshell.Io
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

    IpcHandler {
        target: "shell"
        function reload() { Quickshell.reload(true); }
    }
}
