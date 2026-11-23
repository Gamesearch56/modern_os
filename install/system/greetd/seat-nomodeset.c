/* Hyprland's first frame is a modeset even when a CRTC is already
 * scanning, and the greeter modesets that CRTC off as it leaves. On
 * this panel a modeset retrains the link and the firmware picture is
 * what shows during the retrain. A commit that only replaces the plane
 * buffer does not. Loaded into Hyprland. MODERN_SEAT_KEEP_CRTC is the
 * greeter: its exit must not turn the panel off, or the next compositor
 * modesets from a dark link.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

struct item {
    uint32_t object_id;
    uint32_t property_id;
    uint64_t value;
    uint64_t unused;
};

struct req {
    uint32_t cursor;
    uint32_t size_items;
    struct item *items;
};

static int layout_ok;
static int logged_flip;
static int logged_keep;
static int (*real_commit)(int, const drmModeAtomicReqPtr, uint32_t, void *);

/* libdrm has grown a field on the request item. Trust the layout only
 * when two known properties come back where this build expects them, so
 * a newer library passes commits through instead of crashing Hyprland. */
static void probe_layout(void)
{
    drmModeAtomicReqPtr raw;
    struct req *got;

    raw = drmModeAtomicAlloc();
    if (!raw)
        return;
    if (drmModeAtomicAddProperty(raw, 11, 22, 33) < 0 || drmModeAtomicAddProperty(raw, 44, 55, 66) < 0) {
        drmModeAtomicFree(raw);
        return;
    }
    got = (struct req *)raw;
    if (got->cursor == 2 && got->items && got->items[0].object_id == 11 && got->items[0].property_id == 22 &&
        got->items[0].value == 33 && got->items[1].object_id == 44 && got->items[1].value == 66)
        layout_ok = 1;
    drmModeAtomicFree(raw);
}

int modern_seat_layout_ok(void)
{
    return layout_ok;
}

static char kind_of(int fd, uint32_t id)
{
    drmModeRes *res;
    drmModePlaneRes *planes;
    int i;
    char kind = '?';

    res = drmModeGetResources(fd);
    if (!res)
        return '?';
    for (i = 0; i < res->count_crtcs; i++) {
        if (res->crtcs[i] == id)
            kind = 'r';
    }
    for (i = 0; i < res->count_connectors; i++) {
        if (res->connectors[i] == id)
            kind = 'n';
    }
    drmModeFreeResources(res);
    if (kind != '?')
        return kind;
    planes = drmModeGetPlaneResources(fd);
    if (!planes)
        return '?';
    for (i = 0; i < (int)planes->count_planes; i++) {
        if (planes->planes[i] == id)
            kind = 'p';
    }
    drmModeFreePlaneResources(planes);
    return kind;
}

/* 1 when this property is part of a modeset. *disable is set when the
 * commit would turn the CRTC off. Plane CRTC_ID stays: dropping it
 * would detach the buffer from the controller that is already scanning. */
static int modeset_prop(int fd, uint32_t obj, uint32_t prop, uint64_t value, int *disable)
{
    drmModePropertyPtr info;
    char kind;
    int drop = 0;

    kind = kind_of(fd, obj);
    info = drmModeGetProperty(fd, prop);
    if (!info)
        return 0;
    if (kind == 'r' && (strcmp(info->name, "MODE_ID") == 0 || strcmp(info->name, "ACTIVE") == 0)) {
        drop = 1;
        if (strcmp(info->name, "ACTIVE") == 0 && value == 0)
            *disable = 1;
    }
    if (kind == 'n' && strcmp(info->name, "CRTC_ID") == 0) {
        drop = 1;
        if (value == 0)
            *disable = 1;
    }
    drmModeFreeProperty(info);
    return drop;
}

int drmModeAtomicCommit(int fd, const drmModeAtomicReqPtr req, uint32_t flags, void *user_data)
{
    const struct req *in;
    drmModeAtomicReqPtr slim;
    uint32_t i;
    uint32_t flip;
    int disable = 0;
    int kept = 0;
    int rc;
    int n;

    if (!real_commit)
        real_commit = dlsym(RTLD_NEXT, "drmModeAtomicCommit");
    if (!real_commit)
        return -EINVAL;
    if (!layout_ok || !req || (flags & DRM_MODE_ATOMIC_TEST_ONLY) || !(flags & DRM_MODE_ATOMIC_ALLOW_MODESET))
        return real_commit(fd, req, flags, user_data);

    in = (const struct req *)req;
    slim = drmModeAtomicAlloc();
    if (slim && in->items) {
        for (i = 0; i < in->cursor; i++) {
            struct item it = in->items[i];
            if (modeset_prop(fd, it.object_id, it.property_id, it.value, &disable))
                continue;
            if (drmModeAtomicAddProperty(slim, it.object_id, it.property_id, it.value) >= 0)
                kept++;
        }
    }
    /* Turning the panel off is the greeter leaving. The next compositor
     * would modeset from a dark link and the firmware picture shows.
     * Screen blanking does not set this variable. */
    if (disable && getenv("MODERN_SEAT_KEEP_CRTC")) {
        if (slim)
            drmModeAtomicFree(slim);
        if (!logged_keep) {
            fprintf(stderr, "seat-cover: nomodeset left the CRTC scanning\n");
            logged_keep = 1;
        }
        return 0;
    }
    if (disable || kept == 0) {
        if (slim)
            drmModeAtomicFree(slim);
        return real_commit(fd, req, flags, user_data);
    }
    flip = flags & ~DRM_MODE_ATOMIC_ALLOW_MODESET;
    rc = -EBUSY;
    for (n = 0; n < 8; n++) {
        rc = real_commit(fd, slim, flip, user_data);
        if (rc == 0) {
            drmModeAtomicFree(slim);
            if (!logged_flip) {
                fprintf(stderr, "seat-cover: nomodeset page flip, mode left as it was\n");
                logged_flip = 1;
            }
            return 0;
        }
        if (rc != -EBUSY)
            break;
        usleep(20000);
    }
    drmModeAtomicFree(slim);
    return real_commit(fd, req, flags, user_data);
}

__attribute__((constructor)) static void seat_nomodeset_loaded(void)
{
    probe_layout();
}
