/* Stand-in for libwlroots. Preload live-xkb-cage.so ahead of this file
 * so the helper's dlsym(RTLD_NEXT) lands here. */
#include <stdbool.h>
#include <xkbcommon/xkbcommon.h>

struct wlr_keyboard {
    struct xkb_keymap *map;
};

struct wlr_seat;

struct wlr_keyboard modern_member;
struct wlr_keyboard modern_group;
struct wlr_keyboard *modern_published;

bool wlr_keyboard_set_keymap(struct wlr_keyboard *keyboard, struct xkb_keymap *keymap)
{
    if (keyboard->map)
        xkb_keymap_unref(keyboard->map);
    keyboard->map = xkb_keymap_ref(keymap);
    return true;
}

void wlr_seat_set_keyboard(struct wlr_seat *seat, struct wlr_keyboard *keyboard)
{
    (void)seat;
    modern_published = keyboard;
}
