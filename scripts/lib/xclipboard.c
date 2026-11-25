/* CLIPBOARD on an X display. Gamescope's nested server does not share
   the desktop clipboard, so the launcher bridges the two.
   get | set [owner-file] | watch.
   set writes this window id to owner-file before taking the selection.
   watch writes each new value followed by NUL, and skips events whose
   owner is that window so a host copy is not echoed back. */
#define _POSIX_C_SOURCE 200809L
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static Display *dpy;
static Window win;
static Atom clip, utf8, prop, text_atom;
static char *payload;
static unsigned long payload_n;

static int io_error(Display *d) {
    (void)d;
    _exit(0);
}

static int open_display(void) {
    XSetIOErrorHandler(io_error);
    dpy = XOpenDisplay(NULL);
    if (!dpy)
        return 0;
    win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 1, 1, 0, 0, 0);
    clip = XInternAtom(dpy, "CLIPBOARD", False);
    utf8 = XInternAtom(dpy, "UTF8_STRING", False);
    prop = XInternAtom(dpy, "XCLIPBOARD_PROP", False);
    text_atom = XInternAtom(dpy, "TEXT", False);
    return 1;
}

static void write_owner(const char *path, Window window) {
    FILE *f;
    if (!path || !path[0])
        return;
    f = fopen(path, "w");
    if (!f)
        return;
    fprintf(f, "%lu\n", (unsigned long)window);
    fclose(f);
}

static int owner_is_ours(Window owner) {
    const char *path = getenv("XCLIPBOARD_OWNER_FILE");
    FILE *f;
    unsigned long id = 0;
    if (!path || !path[0])
        return 0;
    f = fopen(path, "r");
    if (!f)
        return 0;
    if (fscanf(f, "%lu", &id) != 1)
        id = 0;
    fclose(f);
    return owner == (Window)id;
}

static char *read_all(unsigned long *n) {
    char *buf;
    size_t cap = 4096;
    size_t len = 0;
    ssize_t got;
    buf = malloc(cap);
    if (!buf)
        return NULL;
    while ((got = read(STDIN_FILENO, buf + len, cap - len)) > 0) {
        len += (size_t)got;
        if (len + 1 >= cap) {
            if (cap >= (1u << 20))
                break;
            cap *= 2;
            buf = realloc(buf, cap);
            if (!buf)
                return NULL;
        }
    }
    *n = (unsigned long)len;
    return buf;
}

static int fetch(char **out, unsigned long *n) {
    XEvent ev;
    Atom actual;
    int format;
    unsigned long left;
    unsigned char *data = NULL;
    Window owner;
    *out = NULL;
    *n = 0;
    owner = XGetSelectionOwner(dpy, clip);
    if (!owner || owner == win)
        return 0;
    XConvertSelection(dpy, clip, utf8, prop, win, CurrentTime);
    XFlush(dpy);
    for (;;) {
        XNextEvent(dpy, &ev);
        if (ev.type != SelectionNotify)
            continue;
        if (ev.xselection.property == None)
            return 0;
        if (XGetWindowProperty(dpy, win, prop, 0, 1 << 20, True, AnyPropertyType,
                &actual, &format, n, &left, &data) != Success)
            return 0;
        *out = (char *)data;
        return 1;
    }
}

static void reply(const XSelectionRequestEvent *req) {
    XSelectionEvent ev;
    Atom types[4];
    memset(&ev, 0, sizeof ev);
    ev.type = SelectionNotify;
    ev.display = req->display;
    ev.requestor = req->requestor;
    ev.selection = req->selection;
    ev.target = req->target;
    ev.time = req->time;
    ev.property = req->property == None ? req->target : req->property;
    if (req->target == XInternAtom(dpy, "TARGETS", False)) {
        types[0] = utf8;
        types[1] = XA_STRING;
        types[2] = text_atom;
        types[3] = XInternAtom(dpy, "TARGETS", False);
        XChangeProperty(dpy, req->requestor, ev.property, XA_ATOM, 32,
            PropModeReplace, (unsigned char *)types, 4);
    } else if (req->target == utf8 || req->target == XA_STRING || req->target == text_atom) {
        XChangeProperty(dpy, req->requestor, ev.property, req->target, 8,
            PropModeReplace, (unsigned char *)(payload ? payload : ""), (int)payload_n);
    } else {
        ev.property = None;
    }
    XSendEvent(dpy, req->requestor, False, 0, (XEvent *)&ev);
    XFlush(dpy);
}

int main(int argc, char **argv) {
    const char *cmd = argc > 1 ? argv[1] : "get";
    char *data = NULL;
    unsigned long n = 0;
    int evbase = 0, errbase = 0;
    pid_t pid;
    XEvent ev;

    if (strcmp(cmd, "set") == 0) {
        payload = read_all(&payload_n);
        pid = fork();
        if (pid < 0)
            return 1;
        if (pid > 0)
            return 0;
        if (setsid() < 0)
            return 1;
        if (!open_display())
            return 1;
        /* Record the window before the selection notify is delivered. */
        write_owner(argc > 2 ? argv[2] : NULL, win);
        XSetSelectionOwner(dpy, clip, win, CurrentTime);
        XFlush(dpy);
        for (;;) {
            XNextEvent(dpy, &ev);
            if (ev.type == SelectionRequest)
                reply(&ev.xselectionrequest);
            else if (ev.type == SelectionClear)
                return 0;
        }
    }

    if (!open_display())
        return 1;
    if (strcmp(cmd, "get") == 0) {
        if (!fetch(&data, &n))
            return 1;
        if (n)
            fwrite(data, 1, n, stdout);
        return 0;
    }
    if (strcmp(cmd, "watch") != 0)
        return 2;
    if (!XFixesQueryExtension(dpy, &evbase, &errbase))
        return 1;
    XFixesSelectSelectionInput(dpy, DefaultRootWindow(dpy), clip,
        XFixesSetSelectionOwnerNotifyMask);
    XFlush(dpy);
    for (;;) {
        XNextEvent(dpy, &ev);
        if (ev.type != evbase + XFixesSelectionNotify)
            continue;
        if (owner_is_ours(((XFixesSelectionNotifyEvent *)&ev)->owner))
            continue;
        if (!fetch(&data, &n))
            continue;
        fwrite(data, 1, n, stdout);
        fputc('\0', stdout);
        fflush(stdout);
        XFree(data);
        data = NULL;
    }
}
