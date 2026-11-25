/* Xwayland translates with the keymap Cage sent. setxkbmap does not
 * change that. Keycode 29 is Y on the US map and Z on the German map.
 * The helper is preloaded and the layout file is German, so the first
 * lookup must already be Z, including while Shift is held. */
#include <xkbcommon/xkbcommon.h>

int main(void)
{
    struct xkb_context *ctx;
    struct xkb_keymap *map;
    struct xkb_state *state;
    struct xkb_rule_names names = {
        .rules = "evdev",
        .model = "pc105",
        .layout = "us",
    };
    xkb_keysym_t sym;

    ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx)
        return 1;
    map = xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!map)
        return 1;
    state = xkb_state_new(map);
    if (!state)
        return 1;
    sym = xkb_state_key_get_one_sym(state, 29);
    if (sym != XKB_KEY_z)
        return 2;
    /* KEY_LEFTSHIFT is evdev 42. XKB keycodes add 8. */
    xkb_state_update_key(state, 50, XKB_KEY_DOWN);
    sym = xkb_state_key_get_one_sym(state, 29);
    if (sym != XKB_KEY_Z)
        return 3;
    return 0;
}
