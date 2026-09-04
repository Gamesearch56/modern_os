// Path classifiers for ConfigWrite. Kept out of the singleton so
// ConfigWrite.qml stays under the lint-layers line cap.
import QtQuick

QtObject {
    function hyprPath(path: string): bool {
        const roots = ["input", "keybinds", "windows", "windowRules", "design", "monitors", "gaming"];
        for (let i = 0; i < roots.length; i++) {
            const r = roots[i];
            if (path === r || path.indexOf(r + ".") === 0)
                return true;
        }
        return false;
    }

    function chromePath(path: string): bool {
        if (path === "typography" || path.indexOf("typography.") === 0)
            return true;
        if (path === "motion" || path.indexOf("motion.") === 0)
            return true;
        const keys = [
            "design.cornerRounding", "design.transparency",
            "design.cursorTheme", "design.cursorSize", "design.iconTheme"
        ];
        for (let i = 0; i < keys.length; i++) {
            if (path === keys[i])
                return true;
        }
        return false;
    }

    function cursorPath(path: string): bool {
        return path === "design" || path === "design.cursorTheme"
            || path === "design.cursorSize";
    }

    function mimePath(path: string): bool {
        return path === "apps.defaults"
            || path.indexOf("apps.defaults.videoPlayer") === 0
            || path.indexOf("apps.defaults.imageViewer") === 0
            || path.indexOf("apps.defaults.fileManager") === 0
            || path.indexOf("apps.defaults.mail") === 0;
    }
}
