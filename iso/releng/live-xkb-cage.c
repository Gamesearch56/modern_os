/* Cage builds its keymap once and Xwayland uses that map for every key.
 * setxkbmap changes the X server, which this compositor ignores, so a
 * German selection still types Y for the key labeled Z. Loaded into
 * cage only. The installer writes /run/modern/xkb-layout. A static
 * screen does not commit a frame and the first selection is not a key,
 * so a thread wakes the compositor loop when the file changes and the
 * map is installed before the next character.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-server-core.h>
#include <xkbcommon/xkbcommon.h>

struct wlr_keyboard;
struct wlr_scene_output;
struct wlr_scene_output_state_options;
struct wlr_seat;

static struct wlr_keyboard *keyboards[8];
static int nkeyboards;
static char applied[160];
static pthread_mutex_t applied_lock = PTHREAD_MUTEX_INITIALIZER;
static int wake_pipe[2] = {-1, -1};
static int seat_needs_push;
static bool (*real_set_keymap)(struct wlr_keyboard *, struct xkb_keymap *);

/* Tests point this at a temp file. The live image uses the path the
 * installer writes. */
static const char *layout_path(void)
{
    const char *p = getenv("MODERN_XKB_LAYOUT");
    if (p && p[0])
        return p;
    return "/run/modern/xkb-layout";
}

static int layout_ok(const char *s)
{
    if (!s || !s[0] || strlen(s) > 32)
        return 0;
    for (; *s; s++) {
        char c = *s;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-'))
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

static int same_applied(const char *spec)
{
    int same;
    pthread_mutex_lock(&applied_lock);
    same = strcmp(spec, applied) == 0;
    pthread_mutex_unlock(&applied_lock);
    return same;
}

static void store_applied(const char *spec)
{
    pthread_mutex_lock(&applied_lock);
    snprintf(applied, sizeof applied, "%s", spec);
    pthread_mutex_unlock(&applied_lock);
}

static int apply_layout(const char *layout, const char *variant)
{
    struct xkb_context *ctx;
    struct xkb_keymap *map;
    struct xkb_rule_names names;
    int pass;
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
    /* A keyboard group copies the member map from inside set_keymap and
     * can put the previous layout back. The second pass runs after that
     * copy, so the layout just written is the one that stays. */
    for (pass = 0; pass < 2; pass++) {
        for (i = 0; i < nkeyboards; i++) {
            if (real_set_keymap(keyboards[i], map))
                ok = 1;
        }
    }
    applying = 0;
    xkb_keymap_unref(map);
    xkb_context_unref(ctx);
    if (!ok)
        return -1;
    /* Cage publishes the group keyboard, not the device, and only when
     * the next key arrives. The device map can already be the new layout
     * while the group still has the previous one. The next
     * wlr_seat_set_keyboard has to install this layout on that keyboard
     * before the client is told. */
    seat_needs_push = 1;
    note(layout);
    return 0;
}

/* force is set when some other caller just installed a keymap. The file
 * still wins, or that call puts the US map back after a German choice. */
static int apply_if_needed(int force)
{
    FILE *f;
    char layout[64];
    char variant[64];
    char spec[160];

    if (!real_set_keymap || nkeyboards == 0)
        return -1;
    f = fopen(layout_path(), "r");
    if (!f)
        return -1;
    layout[0] = 0;
    variant[0] = 0;
    if (!fgets(layout, sizeof layout, f)) {
        fclose(f);
        return -1;
    }
    if (!fgets(variant, sizeof variant, f))
        variant[0] = 0;
    fclose(f);
    layout[strcspn(layout, "\r\n")] = 0;
    variant[strcspn(variant, "\r\n")] = 0;
    if (!layout_ok(layout) || (variant[0] && !layout_ok(variant)))
        return -1;
    snprintf(spec, sizeof spec, "%s\n%s", layout, variant);
    if (!force && same_applied(spec))
        return 0;
    if (apply_layout(layout, variant) != 0)
        return -1;
    store_applied(spec);
    return 0;
}

static void poke_layout(void)
{
    char byte = 'x';
    if (wake_pipe[1] >= 0)
        (void)write(wake_pipe[1], &byte, 1);
}

static void *watch_layout(void *unused)
{
    (void)unused;
    for (;;) {
        FILE *f;
        char layout[64];
        char variant[64];
        char spec[160];

        usleep(100000);
        f = fopen(layout_path(), "r");
        if (!f)
            continue;
        layout[0] = 0;
        variant[0] = 0;
        if (!fgets(layout, sizeof layout, f)) {
            fclose(f);
            continue;
        }
        if (!fgets(variant, sizeof variant, f))
            variant[0] = 0;
        fclose(f);
        layout[strcspn(layout, "\r\n")] = 0;
        variant[strcspn(variant, "\r\n")] = 0;
        if (!layout_ok(layout))
            continue;
        snprintf(spec, sizeof spec, "%s\n%s", layout, variant);
        if (!same_applied(spec))
            poke_layout();
    }
    return NULL;
}

static int on_layout_wake(int fd, uint32_t mask, void *data)
{
    char buf[64];
    (void)mask;
    (void)data;
    while (read(fd, buf, sizeof buf) > 0) {
    }
    if (!real_set_keymap)
        real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
    apply_if_needed(0);
    return 0;
}

static int in_seat;

void wlr_seat_set_keyboard(struct wlr_seat *seat, struct wlr_keyboard *keyboard)
{
    static void (*real)(struct wlr_seat *, struct wlr_keyboard *);
    if (!real)
        real = dlsym(RTLD_NEXT, "wlr_seat_set_keyboard");
    /* The first key after a layout change is what publishes the group
     * keyboard. Installing the file there is what makes the first
     * selection the map the next character uses. Later keys must not
     * compile again or held Shift is dropped. */
    if (keyboard && seat_needs_push && !in_seat) {
        in_seat = 1;
        remember(keyboard);
        if (!real_set_keymap)
            real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
        if (apply_if_needed(1) == 0)
            seat_needs_push = 0;
        in_seat = 0;
    }
    if (real)
        real(seat, keyboard);
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
    apply_if_needed(1);
    return ok;
}

void wlr_seat_keyboard_notify_key(struct wlr_seat *seat, uint32_t time_msec, uint32_t key, uint32_t state)
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

bool wlr_scene_output_commit(struct wlr_scene_output *scene_output, const struct wlr_scene_output_state_options *options)
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

void wl_display_run(struct wl_display *display)
{
    static void (*real)(struct wl_display *);
    struct wl_event_loop *loop;

    if (!real)
        real = dlsym(RTLD_NEXT, "wl_display_run");
    loop = wl_display_get_event_loop(display);
    if (loop && wake_pipe[0] >= 0)
        wl_event_loop_add_fd(loop, wake_pipe[0], WL_EVENT_READABLE, on_layout_wake, NULL);
    if (!real_set_keymap)
        real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
    apply_if_needed(1);
    if (real)
        real(display);
}

__attribute__((constructor)) static void live_xkb_loaded(void)
{
    pthread_t thread;
    note("loaded");
    if (pipe2(wake_pipe, O_CLOEXEC | O_NONBLOCK) != 0) {
        wake_pipe[0] = -1;
        wake_pipe[1] = -1;
        return;
    }
    if (pthread_create(&thread, NULL, watch_layout, NULL) == 0)
        pthread_detach(thread);
}
