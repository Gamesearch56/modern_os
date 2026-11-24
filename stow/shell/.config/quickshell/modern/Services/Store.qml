// Official-repo package store. Search/info via scripts; mutate is
// StoreMutate (pkexec pacman). Upgrades stay in Settings → System.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property string categoryId: "discover"
    property string query: ""
    property string detailName: ""
    property string previewShot: ""
    property var results: []
    property var systemPkgs: []
    property var sections: []
    property int newFrom: -1
    property bool loading: false
    readonly property bool canMutate: Passwd.canManage
    readonly property alias categories: catalog.categories
    readonly property alias popular: catalog.popular
    readonly property alias pendingName: mutate.pendingName
    readonly property alias pendingAction: mutate.pendingAction
    readonly property alias mutating: mutate.mutating
    readonly property alias mutAction: mutate.mutAction
    readonly property alias doneAction: mutate.doneAction
    readonly property alias errorKey: mutate.errorKey
    readonly property alias lastName: mutate.lastName
    readonly property alias log: mutate.log
    readonly property alias authWait: mutate.authWait
    readonly property alias detail: infoBox.info
    readonly property alias shots: infoBox.shots
    readonly property alias detailLoading: infoBox.loading
    readonly property alias hasMore: browse.hasMore
    readonly property alias listEnd: browse.listEnd
    readonly property alias loadingMore: browse.loading
    signal notify(string summary, string body)
    signal listWillGrow()
    signal listDidGrow()

    StoreCatalog {
        id: catalog
        onLoaded: { if (root.open) root.reload(); }
    }
    StoreClassify {
        id: classify
        core: true
        onShippedReadyChanged: {
            if (classify.shippedReady && root.open)
                root.reload();
        }
    }
    StoreMutate {
        id: mutate
        onNotify: (summary, body) => root.notify(summary, body)
        onFinished: (ok) => {
            if (!ok)
                return;
            // The follow-up package query is what used to leave the
            // button on Remove until it returned.
            fetch.noteInstalled(mutate.lastName, mutate.doneAction !== "remove");
            Update.drop(mutate.lastName);
            if (mutate.doneAction === "remove" && mutate.lastName === "ollama")
                Ai.packageGone();
            root.reload();
            if (root.detailName.length)
                infoBox.load(root.detailName);
        }
    }
    StoreBrowse {
        id: browse
        onPage: (rows) => {
            const extra = rows || [];
            if (!extra.length)
                return;
            root.listWillGrow();
            root.newFrom = root.results.length;
            root.results = root.results.concat(extra);
            root.listDidGrow();
        }
    }
    StoreHistory { id: hist; host: root }
    StoreDetail { id: infoBox }
    StoreFetch {
        id: fetch
        host: root
        catalog: catalog
        classify: classify
        browse: browse
        mutate: mutate
    }

    Timer {
        id: searchDebounce
        interval: Motion.mediumMs
        onTriggered: fetch.runSearch()
    }

    Connections {
        target: Settings
        function onOpenChanged() { if (root.open) Update.watching = true; }
        function onSectionIdChanged() { if (root.open) Update.watching = true; }
    }

    function show() {
        root.open = true;
        Passwd.ensureGroups();
        Update.watching = true;
        if (!Update.checking && !Update.running)
            Update.refresh();
        root.reload();
    }
    function showPackage(name: string) {
        const n = String(name || "").trim();
        if (!mutate.validName(n))
            return;
        if (root.detailName !== n || root.query.length)
            hist.push();
        root.query = "";
        root.detailName = n;
        infoBox.load(n);
        root.show();
    }
    function closeDetail() {
        root.closePreview();
        root.detailName = "";
        infoBox.clear();
    }
    function applyNav(s) {
        hist.lock = true;
        root.closePreview();
        root.categoryId = s && s.categoryId ? s.categoryId : "discover";
        root.query = s && s.query ? s.query : "";
        const n = String(s && s.detailName || "").trim();
        if (n.length && mutate.validName(n)) {
            root.detailName = n;
            infoBox.load(n);
        } else {
            root.detailName = "";
            infoBox.clear();
        }
        root.newFrom = -1;
        if (root.query.trim().length > 0)
            fetch.runSearch();
        else
            fetch.reload();
        hist.lock = false;
    }
    function goBack() {
        if (root.previewShot.length) {
            root.closePreview();
            return;
        }
        if (hist.back())
            return;
        if (root.detailName.length) {
            root.closeDetail();
            return;
        }
        if (root.query.length) {
            root.setQuery("");
            return;
        }
        if (root.categoryId !== "discover")
            root.setCategory("discover");
    }
    function goForward() { hist.forward(); }
    function hide() {
        if (mutate.busy && !mutate.authWait)
            return;
        if (mutate.authWait)
            mutate.cancel();
        root.open = false;
        root.closeDetail();
        mutate.cancel();
        mutate.dismissError();
        if (!Settings.open || Settings.sectionId !== "system")
            Update.watching = false;
    }
    function toggle() {
        if (root.open)
            root.hide();
        else
            root.show();
    }
    function setQuery(text: string) {
        const next = String(text || "").slice(0, 80);
        if ((root.query.trim().length > 0) !== (next.trim().length > 0) || root.detailName.length)
            hist.push();
        root.closeDetail();
        root.query = next;
        if (root.query.trim().length > 0) {
            searchDebounce.restart();
            return;
        }
        root.reload();
    }
    function setCategory(id: string) {
        const next = String(id || "discover");
        if (root.categoryId !== next || root.query.length || root.detailName.length)
            hist.push();
        root.closeDetail();
        root.categoryId = next;
        if (root.query.length > 0)
            root.query = "";
        root.reload();
    }
    function requestInstall(name: string) {
        if (root.canMutate)
            mutate.requestInstall(name);
    }
    function requestUpdate(name: string) {
        if (root.canMutate)
            mutate.requestUpdate(name);
    }
    function requestRemove(name: string) {
        if (root.canMutate)
            mutate.requestRemove(name);
    }
    function cancel() { mutate.cancel(); }
    function confirm() { mutate.confirm(); }
    function dismissError() { mutate.dismissError(); }
    function loadMore() { browse.fetch(fetch.seen()); }
    function previewImage(url: string) {
        let u = String(url || "");
        if (u.indexOf("https://screenshots.debian.net/") !== 0)
            return;
        u = u.replace("/thumbnail/", "/screenshot/");
        u = u.replace("/small/", "/screenshot/");
        root.previewShot = u;
    }
    function closePreview() { root.previewShot = ""; }
    function reload() {
        root.newFrom = -1;
        fetch.reload();
    }

    function hasUpdate(name: string): bool {
        void Update.pending;
        const n = String(name || "");
        const rows = Update.pending || [];
        for (let i = 0; i < rows.length; i++) {
            if (String(rows[i] && rows[i].name || "") === n)
                return true;
        }
        return false;
    }
    function iconFor(id: string): string { return catalog.iconFor(id); }
    function iconForPkg(name: string): string {
        const found = catalog.iconForPkg(name);
        return String(found || "").length ? found : classify.iconFor(name);
    }
    function isSystem(name: string): bool { return classify.isSystem(name); }
    function titleFor(name: string): string { return catalog.title(name); }
    function descFor(name: string, fallback: string): string {
        return catalog.desc(name, fallback);
    }
    // The launcher the dock pins for an installed package: one it ships
    // (`desktop` from pkg-detail.sh) that the launcher lists, preferring
    // the package's own name over helpers like kitty-open.
    function dockIdFor(name: string, ids: var): string {
        const shown = {};
        const entries = Apps.allEntries();
        for (let i = 0; i < entries.length; i++)
            shown[String(entries[i].value || "").replace(/\.desktop$/i, "").toLowerCase()] = true;
        const want = String(name || "").toLowerCase();
        const list = (ids || []).map(String).filter(id => shown[id.toLowerCase()]);
        return list.find(id => id.toLowerCase() === want) || list[0] || "";
    }

    IpcHandler {
        target: "store"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
        function showPackage(name: string): void { root.showPackage(name); }
    }
}
