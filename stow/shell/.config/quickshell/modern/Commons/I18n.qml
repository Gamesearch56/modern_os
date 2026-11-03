// Reactive translation lookup over ~/.config/modern/translations/{en,de}.json
// (docs/ARCHITECTURE.md's "i18n" section). Mirrors install/lib/i18n.sh's
// shell-side behavior: dot-path keys, English fallback for missing keys,
// `{param}` interpolation. Two FileViews (active language + fallback) so a
// key present in en.json but not yet translated in de.json still resolves —
// translators can add strings incrementally without breaking the UI.
//
// Usage: I18n.t("bar.volume") / I18n.t("powerMenu.confirmBody", { action: "shut down", seconds: 10 })
//
// Named `t()`, not `tr()` — purely to sidestep ever wondering whether it
// collides with QtObject's inherited `tr()` (Qt Linguist). It doesn't,
// in practice (verified), but `t()` is one character shorter and settles
// the question for good. See docs/DECISIONS.md #18.
//
// A desktop update rewrites these files in place (git checkout/merge in
// desktop-sync.sh), so the watcher can fire on a missing or half-written
// copy. The last good table stays in use and the file is read again;
// only a file still broken after `_maxTries` reads is reported.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string activeLang: Config.language.ui ?? "en"
    readonly property string fallbackLang: Config.language.fallback ?? "en"
    readonly property int _maxTries: 8

    property var _active: ({})
    property var _fallback: ({})
    property int _gen: 0

    FileView {
        id: activeFile
        path: `${root.home}/.config/modern/translations/${root.activeLang}.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const table = root._parse(text(), activeRetry, root.activeLang);
            if (table !== null) {
                root._active = table;
                root._gen++;
            }
        }
        onLoadFailed: (error) => {
            if (root._again(activeRetry))
                return;
            Logger.warn("I18n", `failed to load "${root.activeLang}.json" (${error}) — falling back to "${root.fallbackLang}" only`);
            root._active = ({});
            root._gen++;
        }
    }

    // Loaded even when activeLang === fallbackLang (harmless duplicate
    // read) — keeps this component free of a conditional-FileView special
    // case for the common case where the user's UI language IS English.
    FileView {
        id: fallbackFile
        path: `${root.home}/.config/modern/translations/${root.fallbackLang}.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const table = root._parse(text(), fallbackRetry, root.fallbackLang);
            if (table !== null) {
                root._fallback = table;
                root._gen++;
            }
        }
        onLoadFailed: (error) => {
            if (root._again(fallbackRetry))
                return;
            Logger.warn("I18n", `failed to load fallback "${root.fallbackLang}.json" (${error})`);
            root._fallback = ({});
            root._gen++;
        }
    }

    Timer {
        id: activeRetry
        property int tries: 0
        interval: Math.max(Motion.fileSettleMs, 1)
        onTriggered: activeFile.reload()
    }

    Timer {
        id: fallbackRetry
        property int tries: 0
        interval: Math.max(Motion.fileSettleMs, 1)
        onTriggered: fallbackFile.reload()
    }

    // Schedules another read; false once the retries are used up.
    function _again(retry: var): bool {
        if (retry.tries >= root._maxTries) {
            retry.tries = 0;
            return false;
        }
        retry.tries++;
        retry.restart();
        return true;
    }

    // The parsed table, or null while the file is still being rewritten.
    function _parse(raw: string, retry: var, lang: string): var {
        try {
            const table = JSON.parse(raw);
            retry.tries = 0;
            return table;
        } catch (e) {
            if (!root._again(retry))
                Logger.error("I18n", `parse failed for "${lang}.json": ${e}`);
            return null;
        }
    }

    function _lookup(table: var, path: string): var {
        let node = table;
        for (const segment of path.split(".")) {
            if (node === undefined || node === null || typeof node !== "object")
                return undefined;
            node = node[segment];
        }
        return node;
    }

    function _interpolate(str: string, params: var): string {
        if (!params)
            return str;
        return str.replace(/\{(\w+)\}/g, (match, name) => {
            const v = params[name];
            return v === undefined || v === null ? match : String(v);
        });
    }

    function t(path: string, params: var): string {
        void root._gen;
        let value = root._lookup(root._active, path);
        if (value === undefined)
            value = root._lookup(root._fallback, path);
        if (value === undefined) {
            Logger.warn("I18n", `missing key "${path}"`);
            return path;
        }
        return root._interpolate(value, params);
    }
}
