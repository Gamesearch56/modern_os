/* Calls the helper the way cage does. This object is not preloaded, so
 * its wlr_* symbols bind to the helper, and the helper's next symbols
 * bind to the stand-in. */
#include <stdbool.h>
#include <xkbcommon/xkbcommon.h>

struct wlr_keyboard {
    struct xkb_keymap *map;
};

struct wlr_seat;

extern struct wlr_keyboard modern_member;
extern struct wlr_keyboard modern_group;
extern struct wlr_keyboard *modern_published;
extern bool wlr_keyboard_set_keymap(struct wlr_keyboard *keyboard, struct xkb_keymap *keymap);
extern void wlr_seat_set_keyboard(struct wlr_seat *seat, struct wlr_keyboard *keyboard);

static int key_is_z(struct xkb_keymap *keymap)
{
    const xkb_keysym_t *syms = NULL;
    int n;

    if (!keymap)
        return 0;
    n = xkb_keymap_key_get_syms_by_level(keymap, 29, 0, 0, &syms);
    return n > 0 && syms && syms[0] == XKB_KEY_z;
}

int modern_seat_test(void)
{
    struct xkb_context *ctx;
    struct xkb_rule_names names;
    struct xkb_keymap *us;

    ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx)
        return 2;
    names.rules = "evdev";
    names.model = "pc105";
    names.layout = "us";
    names.variant = NULL;
    names.options = NULL;
    us = xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!us)
        return 2;
    wlr_keyboard_set_keymap(&modern_member, us);
    wlr_keyboard_set_keymap(&modern_group, us);
    /* The group still has the previous layout when the first key asks
     * the seat to publish it. */
    if (modern_group.map)
        xkb_keymap_unref(modern_group.map);
    modern_group.map = xkb_keymap_ref(us);
    wlr_seat_set_keyboard(NULL, &modern_group);
    if (!modern_published || modern_published != &modern_group || !key_is_z(modern_published->map))
        return 4;
    modern_published = NULL;
    wlr_seat_set_keyboard(NULL, &modern_group);
    if (!modern_published || !key_is_z(modern_published->map))
        return 5;
    return 0;
}
