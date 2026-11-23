// Hyprland keeps each window's own cursor image, so swapping the theme
// only changes the pointer on surfaces that ask again. This plugin holds
// the watch shape above those images until the launch ends. Clicks are
// unchanged: the override is only the picture.
#include <string>

#include <hyprland/src/ipc/s1/S1.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/pointer/cursor/CursorShapeOverrideController.hpp>

using namespace Pointer::Cursor;

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

static std::string shapeOf(const std::string& command) {
    const auto at = command.find("begin ");
    if (at == std::string::npos)
        return "left_ptr_watch";
    auto shape = command.substr(at + 6);
    while (!shape.empty() && (shape.back() == ' ' || shape.back() == '\n' || shape.back() == '\r'))
        shape.pop_back();
    if (shape.empty())
        return "left_ptr_watch";
    for (const char c : shape) {
        const auto ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-';
        if (!ok)
            return "left_ptr_watch";
    }
    return shape;
}

static IPC::Socket1::SResponse onCommand(const IPC::Socket1::SRequest& request) {
    if (!overrideController)
        return IPC::Socket1::SResponse{"no controller"};
    if (request.command.find("end") != std::string::npos) {
        overrideController->unsetOverride(CURSOR_OVERRIDE_UNKNOWN);
        return IPC::Socket1::SResponse{"ok"};
    }
    overrideController->setOverride(shapeOf(request.command), CURSOR_OVERRIDE_UNKNOWN);
    return IPC::Socket1::SResponse{"ok"};
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    HyprlandAPI::registerHyprCtlCommand(handle, IPC::Socket1::SCommand{
        .name    = "cursorbusy",
        .match   = IPC::Socket1::COMMAND_MATCH_PREFIX,
        .handler = onCommand,
    });
    return {"modern-cursor-busy", "Pointer while a program is opening", "modern", "1"};
}
