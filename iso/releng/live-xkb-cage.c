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
#include <stdio.h>
#include <string.h>
#include <xkbcommon/xkbcommon.h>

struct wlr_keyboard;
struct wlr_scene_output;
struct wlr_scene_output_state_options;

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

static void apply_layout(const char *layout, const char *variant)
{
    struct xkb_context *ctx;
    struct xkb_keymap *map;
    struct xkb_rule_names names;
    int i;

    if (!real_set_keymap || nkeyboards == 0)
        return;
    ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!ctx)
        return;
    memset(&names, 0, sizeof names);
    names.rules = "evdev";
    names.model = "pc105";
    names.layout = layout;
    names.variant = (variant && variant[0]) ? variant : NULL;
    map = xkb_keymap_new_from_names(ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!map) {
        note("keymap compile failed");
        xkb_context_unref(ctx);
        return;
    }
    for (i = 0; i < nkeyboards; i++)
        (void)real_set_keymap(keyboards[i], map);
    xkb_keymap_unref(map);
    xkb_context_unref(ctx);
    note(layout);
}

static void maybe_reload(void)
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
    if (strcmp(spec, applied) == 0)
        return;
    /* Record first. set_keymap can re-enter the event loop, and a
     * second read of the same file must not apply it again. */
    snprintf(applied, sizeof applied, "%s", spec);
    apply_layout(layout, variant);
}

bool wlr_keyboard_set_keymap(struct wlr_keyboard *keyboard, struct xkb_keymap *keymap)
{
    bool ok = false;
    if (!real_set_keymap)
        real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
    remember(keyboard);
    if (real_set_keymap)
        ok = real_set_keymap(keyboard, keymap);
    maybe_reload();
    return ok;
}

bool wlr_scene_output_commit(struct wlr_scene_output *scene_output,
    const struct wlr_scene_output_state_options *options)
{
    static bool (*real)(struct wlr_scene_output *, const struct wlr_scene_output_state_options *);
    if (!real)
        real = dlsym(RTLD_NEXT, "wlr_scene_output_commit");
    maybe_reload();
    if (!real)
        return false;
    return real(scene_output, options);
}
