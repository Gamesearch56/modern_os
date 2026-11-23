/* Cage builds its keymap once and Xwayland translates every key with
 * that map. setxkbmap updates the names `setxkbmap -query` prints and
 * then warns that this is an Xwayland server; the next key is still
 * translated from the map Cage sent. The installer writes
 * /run/modern/xkb-layout. This library is already loaded into Xwayland
 * (Cage starts it with the preload still set). Keysym lookups use the
 * file, so the first selection types correctly even when Cage never
 * calls the wlroots keymap symbol this library also wraps.
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
static bool (*real_set_keymap)(struct wlr_keyboard *, struct xkb_keymap *);
/* The layout last published on each keyboard. A global "applied" flag
 * can be set by updating the device while the group Cage publishes
 * still has the previous map, and the first selection then never shows. */
static struct {
    struct wlr_keyboard *kb;
    char spec[160];
} pushed[8];

/* Tests point this at a temp file. The live image uses the path the
 * installer writes. */
static const char *layout_path(void)
{
    const char *p = getenv("MODERN_XKB_LAYOUT");
    if (p && p[0])
        return p;
    return "/run/modern/xkb-layout";
}

static void push_xwayland(const char *layout, const char *variant);

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
    static const char *const paths[] = {
        "/run/modern/installer/xkb.log",
        "/tmp/live-xkb-cage.log",
        NULL
    };
    FILE *f = NULL;
    int i;
    for (i = 0; paths[i]; i++) {
        f = fopen(paths[i], "a");
        if (f)
            break;
    }
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
static int noted_layout_fail;

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
    push_xwayland(layout, variant);
    note(layout);
    return 0;
}

/* Xwayland can ignore a keymap sent after it has already entered.
 * setxkbmap updates the X map directly. Only the live session asks for
 * this; a test must not change the machine it runs on. */
static void push_xwayland(const char *layout, const char *variant)
{
    const char *flag;
    pid_t pid;

    flag = getenv("MODERN_XKB_PUSH_X");
    if (!flag || flag[0] != '1')
        return;
    pid = fork();
    if (pid != 0)
        return;
    if (!getenv("DISPLAY"))
        setenv("DISPLAY", ":0", 0);
    if (variant && variant[0])
        execlp("setxkbmap", "setxkbmap", "-layout", layout, "-variant", variant, (char *)NULL);
    else
        execlp("setxkbmap", "setxkbmap", "-layout", layout, (char *)NULL);
    _exit(127);
}

static int read_spec(char *spec, size_t spec_len)
{
    FILE *f;
    char layout[64];
    char variant[64];

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
    snprintf(spec, spec_len, "%s\n%s", layout, variant);
    return 0;
}

static int already_pushed(struct wlr_keyboard *kb, const char *spec)
{
    int i;
    for (i = 0; i < 8; i++) {
        if (pushed[i].kb == kb)
            return strcmp(pushed[i].spec, spec) == 0;
    }
    return 0;
}

static void mark_pushed(const char *spec)
{
    int i;
    for (i = 0; i < nkeyboards; i++) {
        int j;
        int free_slot = -1;
        for (j = 0; j < 8; j++) {
            if (pushed[j].kb == keyboards[i]) {
                snprintf(pushed[j].spec, sizeof pushed[j].spec, "%s", spec);
                free_slot = -2;
                break;
            }
            if (pushed[j].kb == NULL && free_slot < 0)
                free_slot = j;
        }
        if (free_slot >= 0) {
            pushed[free_slot].kb = keyboards[i];
            snprintf(pushed[free_slot].spec, sizeof pushed[free_slot].spec, "%s", spec);
        }
    }
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
    if (apply_layout(layout, variant) != 0) {
        /* The file is the layout the user picked. Saying so once is
         * enough: repeating it on every key hides the first failure. */
        if (!noted_layout_fail)
            note("layout was not installed");
        noted_layout_fail = 1;
        return -1;
    }
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

/* Xwayland's xkb_state was built from Cage's map. These lookups are
 * what turn a keycode into the character Calamares inserts. */
static struct xkb_context *client_ctx;
static struct xkb_keymap *client_map;
static struct xkb_state *client_state;
static char client_spec[160];
static pthread_mutex_t client_lock = PTHREAD_MUTEX_INITIALIZER;

static int ensure_client_layout(void);

static struct xkb_state *client_layout_state(void)
{
    struct xkb_state *mine = NULL;
    if (ensure_client_layout()) {
        pthread_mutex_lock(&client_lock);
        mine = client_state;
        pthread_mutex_unlock(&client_lock);
    }
    return mine;
}

static int ensure_client_layout(void)
{
    char spec[160];
    char layout[64];
    char variant[64];
    struct xkb_rule_names names;
    struct xkb_keymap *map;
    struct xkb_state *state;
    const char *split;

    if (read_spec(spec, sizeof spec) != 0)
        return 0;
    pthread_mutex_lock(&client_lock);
    if (client_state && strcmp(spec, client_spec) == 0) {
        pthread_mutex_unlock(&client_lock);
        return 1;
    }
    pthread_mutex_unlock(&client_lock);
    split = strchr(spec, '\n');
    if (!split || (size_t)(split - spec) >= sizeof layout)
        return 0;
    memcpy(layout, spec, (size_t)(split - spec));
    layout[split - spec] = 0;
    snprintf(variant, sizeof variant, "%s", split + 1);
    if (!client_ctx)
        client_ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!client_ctx)
        return 0;
    memset(&names, 0, sizeof names);
    names.rules = "evdev";
    names.model = "pc105";
    names.layout = layout;
    names.variant = variant[0] ? variant : NULL;
    map = xkb_keymap_new_from_names(client_ctx, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!map) {
        note("keymap compile failed");
        return 0;
    }
    state = xkb_state_new(map);
    if (!state) {
        xkb_keymap_unref(map);
        return 0;
    }
    pthread_mutex_lock(&client_lock);
    if (client_state)
        xkb_state_unref(client_state);
    if (client_map)
        xkb_keymap_unref(client_map);
    client_map = map;
    client_state = state;
    snprintf(client_spec, sizeof client_spec, "%s", spec);
    pthread_mutex_unlock(&client_lock);
    note(layout);
    return 1;
}

int xkb_state_key_get_syms(struct xkb_state *state, xkb_keycode_t key, const xkb_keysym_t **syms_out)
{
    static int (*real)(struct xkb_state *, xkb_keycode_t, const xkb_keysym_t **);
    struct xkb_state *mine;
    if (!real)
        real = dlsym(RTLD_NEXT, "xkb_state_key_get_syms");
    if (!real)
        return 0;
    mine = client_layout_state();
    if (mine && mine != state)
        return real(mine, key, syms_out);
    return real(state, key, syms_out);
}

enum xkb_state_component xkb_state_update_key(struct xkb_state *state, xkb_keycode_t key, enum xkb_key_direction direction)
{
    static enum xkb_state_component (*real)(struct xkb_state *, xkb_keycode_t, enum xkb_key_direction);
    struct xkb_state *mine;
    if (!real)
        real = dlsym(RTLD_NEXT, "xkb_state_update_key");
    mine = client_layout_state();
    if (real && mine && mine != state)
        real(mine, key, direction);
    if (!real)
        return 0;
    return real(state, key, direction);
}

int xkb_state_key_get_utf8(struct xkb_state *state, xkb_keycode_t key, char *buffer, size_t size)
{
    static int (*real)(struct xkb_state *, xkb_keycode_t, char *, size_t);
    struct xkb_state *mine;
    if (!real)
        real = dlsym(RTLD_NEXT, "xkb_state_key_get_utf8");
    if (!real)
        return 0;
    mine = client_layout_state();
    if (mine && mine != state)
        return real(mine, key, buffer, size);
    return real(state, key, buffer, size);
}

uint32_t xkb_state_key_get_utf32(struct xkb_state *state, xkb_keycode_t key)
{
    static uint32_t (*real)(struct xkb_state *, xkb_keycode_t);
    struct xkb_state *mine;
    if (!real)
        real = dlsym(RTLD_NEXT, "xkb_state_key_get_utf32");
    if (!real)
        return 0;
    mine = client_layout_state();
    if (mine && mine != state)
        return real(mine, key);
    return real(state, key);
}

static int in_seat;

void wlr_seat_set_keyboard(struct wlr_seat *seat, struct wlr_keyboard *keyboard)
{
    static void (*real)(struct wlr_seat *, struct wlr_keyboard *);
    char spec[160];
    if (!real)
        real = dlsym(RTLD_NEXT, "wlr_seat_set_keyboard");
    /* Cage publishes the group keyboard on the key, not the device the
     * file watcher updated. Install the file on this keyboard before
     * the client is told, and only once per layout so Shift survives. */
    if (keyboard && !in_seat) {
        in_seat = 1;
        remember(keyboard);
        if (!real_set_keymap)
            real_set_keymap = dlsym(RTLD_NEXT, "wlr_keyboard_set_keymap");
        if (read_spec(spec, sizeof spec) == 0 && !already_pushed(keyboard, spec)) {
            if (apply_if_needed(1) == 0)
                mark_pushed(spec);
        }
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
