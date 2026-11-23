/* Cage builds its keymap once and Xwayland uses that map for every key.
 * setxkbmap changes the X server, which this compositor ignores, so a
 * German selection still types Y for the key labeled Z. Loaded into
 * cage only. Each frame cage commits reads /run/modern/xkb-layout and,
 * when the file changes, installs that map on the keyboards cage has
 * already created. The commit is called from cage itself, so this
 * interposition runs; a hook inside libwayland would not.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <xkbcommon/xkbcommon.h>

struct wlr_keyboard;
struct wlr_scene_output;
struct wlr_scene_output_state_options;
struct wlr_seat;

static struct wlr_keyboard *keyboards[8];
static int nkeyboards;
static char applied[160];
static bool (*real_set_keymap)(struct wlr_keyboard *, struct xkb_keymap *);

static int layout_ok(const char *s)
{
    if (!s || !s[0] || strlen(s) > 32)
        return 0;
    for (; *s; s++) {
        char c = *s;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '-'))
            return 0;
    }
    return 1;
}

static void note(const char *msg)
{
    FILE *f = fopen("/tmp/live-xkb-cage.log", "a");
    if (!f)
        return;
    fputs(msg, f);
    fputc('\n', f);
    fclose(f);
}

static void remember(struct wlr_keyboard *kb)
{
    int i;
    if (!kb)
        return;
    for (i = 0; i < nkeyboards; i++) {
        if (keyboards[i] == kb)
            return;
    }
    if (nkeyboards < 8)
        keyboards[nkeyboards++] = kb;
}

static int applying;

static int apply_layout(const char *layout, const char *variant)
{
    struct xkb_context *ctx;
    struct xkb_keymap *map;
    struct xkb_rule_names names;
    int i;
    int ok = 0;

    if (!real_set_keymap || nkeyboards == 0)
        return -1;
    ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx)
        return -1;
    memset(&names, 0, sizeof names);
    names.rules = "evdev";
    names.model = "pc105";
    names.layout = layout;
    names.variant = (variant && variant[0]) ? variant : NULL;
    map = xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!map) {
        note("keymap compile failed");
        xkb_context_unref(ctx);
        return -1;
    }
    applying = 1;
    for (i = 0; i < nkeyboards; i++) {
        if (real_set_keymap(keyboards[i], map))
            ok = 1;
    }
    applying = 0;
    xkb_keymap_unref(map);
    xkb_context_unref(ctx);
    if (!ok)
        return -1;
    note(layout);
    return 0;
}

/* force is set when some other caller just installed a keymap. The file
 * still wins, or that call puts the US map back after a German choice. */
static void apply_if_needed(int force)
{
    FILE *f;
    char layout[64];
    char variant[64];
    char spec[160];

    if (!real_set_keymap || nkeyboards == 0)
        return;
    f = fopen("/run/modern/xkb-layout", "r");
    if (!f)
        return;
    layout[0] = 0;
    variant[0] = 0;
    if (!fgets(layout, sizeof layout, f)) {
        fclose(f);
        return;
    }
    if (!fgets(variant, sizeof variant, f))
        variant[0] = 0;
    fclose(f);
    layout[strcspn(layout, "\r\n")] = 0;
    variant[strcspn(variant, "\r\n")] = 0;
    if (!layout_ok(layout) || (variant[0] && !layout_ok(variant)))
        return;
    snprintf(spec, sizeof spec, "%s\n%s", layout, variant);
    if (!force && strcmp(spec, applied) == 0)
        return;
    if (apply_layout(layout, variant) != 0)
        return;
    snprintf(applied, sizeof applied, "%s", spec);
}

bool wlr_keyboard_set_keymap(struct wlr_keyboard *keyboard, struct xkb_keymap *keymap)
{
    bool ok = false;
    if (!real_set_keymap)
        real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
    if (applying) {
        if (!real_set_keymap)
            return false;
        return real_set_keymap(keyboard, keymap);
    }
    remember(keyboard);
    if (real_set_keymap)
        ok = real_set_keymap(keyboard, keymap);
    /* A keyboard group copies the member map and can write the old one
     * back. The file the installer just wrote is the one the next key uses. */
    apply_if_needed(1);
    return ok;
}

void wlr_seat_keyboard_notify_key(struct wlr_seat *seat, uint32_t time_msec,
    uint32_t key, uint32_t state)
{
    static void (*real)(struct wlr_seat *, uint32_t, uint32_t, uint32_t);
    if (!real)
        real = dlsym(RTLD_NEXT, "wlr_seat_keyboard_notify_key");
    /* The keycode is translated by Xwayland with the keymap it has now.
     * Install the chosen layout before this key is delivered. */
    apply_if_needed(0);
    if (real)
        real(seat, time_msec, key, state);
}

bool wlr_scene_output_commit(struct wlr_scene_output *scene_output,
    const struct wlr_scene_output_state_options *options)
{
    static bool (*real)(struct wlr_scene_output *, const struct wlr_scene_output_state_options *);
    if (!real)
        real = dlsym(RTLD_NEXT, "wlr_scene_output_commit");
    if (!real_set_keymap)
        real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
    apply_if_needed(0);
    if (!real)
        return false;
    return real(scene_output, options);
}

__attribute__((constructor)) static void live_xkb_loaded(void)
{
    note("loaded");
}
