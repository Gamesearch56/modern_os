// Reactive, read-only view of ~/.config/modern/config.json — see
// docs/ARCHITECTURE.md's "Config layer" and docs/DECISIONS.md #3 (the
// Settings app is the only writer; this singleton never calls
// writeAdapter(), matching stow/hypr/.config/hypr/modules/config.lua's
// same read-only stance on the Hyprland side).
//
// Every property below mirrors stow/modern/.config/modern/config.default.json
// 1:1 — that file is the authoritative schema; this is its QML-typed
// reflection. Sections with a fixed, simple shape are declared as typed
// JsonObject sub-adapters (get individual change signals, e.g.
// `onScaleChanged`); sections that are free-form, widget-specific, or not
// yet consumed anywhere use a plain `var` blob instead of hand-typing
// every nested key twice — see docs/DECISIONS.md. Promote a `var` section
// to a typed JsonObject once a consumer needs granular reactivity on one
// of its keys specifically.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property int _configMisses: 0

    FileView {
        id: file
        path: `${root.home}/.config/modern/config.json`
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: root._configMisses = 0
        onLoadFailed: (error) => {
            // FileNotFound (2): atomic replace can fire the watcher between
            // unlink and rename. Retry; do not toast.
            if (error === FileViewError.FileNotFound && root._configMisses < 8) {
                root._configMisses++;
                Qt.callLater(() => file.reload());
                return;
            }
            Logger.error("Config", "failed to load config.json: " + error);
        }

        JsonAdapter {
            id: adapter

            property JsonObject general: JsonObject {
                property list<string> autostart: ["proton-mail.desktop"]
                property int notificationTimeoutMs: 6000
                property JsonObject dndSchedule: JsonObject {
                    property bool enabled: false
                    property string from: "23:00"
                    property string to: "07:00"
                }
                property JsonObject idleTimings: JsonObject {
                    property int dimSec: 120
                    property int screenOffSec: 300
                    property int lockSec: 600
                    property int suspendSec: 1800
                }
                property bool autologin: false
            }

            property JsonObject motion: JsonObject {
                property real scale: 1.0
                property string overlay: "fadeZoom"
            }

            property JsonObject typography: JsonObject {
                property string ui: "Inter" // JSON key "ui", not "interface" — reserved QML identifier, see docs/DECISIONS.md
                property string document: "Inter"
                property string monospace: "JetBrainsMono Nerd Font"
                property real scale: 1.0
                property int weight: 400
            }

            property JsonObject design: JsonObject {
                property string activeProfile: "tonal-spot-dark"
                property real cornerRounding: 1.0
                property real transparency: 0.85
                property real surfaceTint: 0.7
                property int blurStrength: 40
                property string iconTheme: "Papirus-Dark"
                property string cursorTheme: "Bibata-Modern-Classic"
                property int cursorSize: 24
                property JsonObject bootScreen: JsonObject {
                    property string mode: "static"
                    property bool wallpaperOnSplash: true
                    property bool wallpaperOnLock: true
                    property bool wallpaperOnLogin: true
                    property bool wallpaperOnVivaldi: true
                }
            }

            property JsonObject language: JsonObject {
                property string ui: "de" // JSON key "ui", not "interface" — reserved QML identifier, see docs/DECISIONS.md
                property string fallback: "en"
                property string dateFormat: "DD.MM.YYYY"
                property string timeFormat: "HH:mm"
                property int firstDayOfWeek: 1
                property string previewDate: ""
                property string timezone: ""
            }

            property JsonObject bar: JsonObject {
                property string position: "top"
                property string style: "floating"
                property int height: 36
                property int edgeGap: 8
                property int endGap: 8
                property bool autoHide: false
                property JsonObject perMonitor: JsonObject {
                    property bool enabled: true
                }
                property list<string> left: ["launcher", "ai", "workspaces", "media"]
                property list<string> center: ["clock"]
                property list<string> right: ["weather", "connectivity", "audio", "taskbar", "battery", "settings", "power"]
            }

            // Per-widget settings blobs — shape varies per widget, each
            // widget reads its own key (e.g. Config.widgets.clock).
            property var widgets: ({
                clock: { dateFormat: "DD.MM.YYYY", timeFormat: "HH:mm", showSeconds: false, showWeekday: false },
                weather: { locationMode: "auto", manualLocation: "", units: "metric" },
                performance: { pollIntervalMs: 2000, showGpu: true, showTemps: true },
                audio: { scrollStepPercent: 5, scrollStepFinePercent: 1 }
            })

            // Per-monitor profiles (keyed by "description + serial") and
            // workspace-assignment rules — see docs/ARCHITECTURE.md
            // "Monitors". Free-form since the key set is per-machine.
            property var monitors: ({ profiles: ({}), rules: [], workspaceMode: "fixed" })

            property var windowRules: []

            property JsonObject windows: JsonObject {
                property bool titlebar: true
                property real opacity: 1.0
                property int gapsIn: 5
                property int gapsOut: 10
            }

            property JsonObject apps: JsonObject {
                property JsonObject defaults: JsonObject {
                    property string browser: "vivaldi-stable.desktop"
                    property string calendar: "proton-mail.desktop"
                    property string mail: "proton-mail.desktop"
                    property string communication: ""
                    property string fileManager: "org.kde.dolphin.desktop"
                    property string terminal: "kitty.desktop"
                }
            }

            property JsonObject input: JsonObject {
                property string kbLayout: "de"
                property string kbVariant: ""
                property int repeatRate: 25
                property int repeatDelay: 600
                property bool numlockOnBoot: true
            }

            property JsonObject launcher: JsonObject {
                property var providers: ({
                    apps: { enabled: true, prefix: "" },
                    shell: { enabled: true, prefix: ">" },
                    calculator: { enabled: true, prefix: "=" },
                    websearch: { enabled: true, prefix: "?" },
                    emoji: { enabled: true, prefix: ":" },
                    files: { enabled: true, prefix: "/" },
                    windows: { enabled: true, prefix: "w " }
                })
                property bool frecencyEnabled: true
                property int mostUsedGridSize: 8
                property int resultCount: 9
                property bool showIcons: true
                property bool showDescriptions: true
            }

            property JsonObject power: JsonObject {
                property string buttonAction: "ask"
                property string lidActionAc: "lock"
                property string lidActionBattery: "suspend"
                property bool inhibitOnFullscreen: true
                property bool inhibitOnMedia: true
            }

            property JsonObject screenshots: JsonObject {
                property string directory: "~/Pictures/Screenshots"
                property string filenameTemplate: "screenshot-%Y%m%d-%H%M%S"
                property string format: "png"
                property int quality: 90
                property bool copyToClipboard: true
                property bool openEditorAfterCapture: false
                property bool includeCursor: false
            }

            property JsonObject audio: JsonObject {
                property string autoSwitchBluetooth: "ask"
                property var perAppVolume: ({})
                property int masterVolumeLimit: 100
            }

            property var network: ({ wifiAutoconnectPriority: ({}), dnsOverride: [], mirrorCountry: "Germany" })

            property JsonObject kdeconnect: JsonObject {
                property bool enabled: true
                property bool mirrorNotifications: true
                property bool sharedClipboard: true
            }

            property var accounts: ({
                protonDrive: { enabled: false },
                calendarIcsUrl: "",
                ai: { provider: "ollama", ollamaModel: "llama3" }
            })

            property var gaming: ({
                profiles: ({}),
                protonWayland: false,
                hdrSession: false,
                systemFixes: { vmMaxMapCount: true, fileDescriptorLimits: true, splitLockMitigate: false },
                optiscaler: { trackedGames: ({}) }
            })

            property JsonObject backup: JsonObject {
                property bool snapperEnabled: false
                property bool resticEnabled: false
                property bool preUpdateSnapshot: true
            }

            // Combo strings use Hyprland's Lua hl.bind() format:
            // "MOD + MOD + KEY" — see config.default.json's own
            // "_comment" key and Modules/Cheatsheet, which reads this
            // same object to render the SUPER+K overlay.
            property var keybinds: ({
                launcher: "SUPER + SPACE",
                aiChat: "SUPER + A",
                powerMenu: "SUPER + M",
                controlCenter: "SUPER + L",
                cheatsheet: "SUPER + K",
                settings: "SUPER + I",
                wallpaperPicker: "SUPER + W",
                overview: "SUPER + TAB",
                terminal: "SUPER + T",
                browser: "SUPER + B",
                browserIncognito: "SUPER + SHIFT + B",
                fileManager: "SUPER + E",
                spotify: "SUPER + R",
                closeWindow: "SUPER + Q",
                fullscreen: "SUPER + F",
                toggleFloating: "SUPER + V",
                pseudoTile: "SUPER + P",
                toggleSplit: "SUPER + J",
                moveFocusLeft: "SUPER + LEFT",
                moveFocusRight: "SUPER + RIGHT",
                moveFocusUp: "SUPER + UP",
                moveFocusDown: "SUPER + DOWN",
                moveWindowLeft: "SUPER + SHIFT + LEFT",
                moveWindowRight: "SUPER + SHIFT + RIGHT",
                moveWindowUp: "SUPER + SHIFT + UP",
                moveWindowDown: "SUPER + SHIFT + DOWN",
                workspace1: "SUPER + 1", workspace2: "SUPER + 2", workspace3: "SUPER + 3",
                workspace4: "SUPER + 4", workspace5: "SUPER + 5", workspace6: "SUPER + 6",
                workspace7: "SUPER + 7", workspace8: "SUPER + 8", workspace9: "SUPER + 9",
                workspace10: "SUPER + 0",
                moveToWorkspace1: "SUPER + SHIFT + 1", moveToWorkspace2: "SUPER + SHIFT + 2",
                moveToWorkspace3: "SUPER + SHIFT + 3", moveToWorkspace4: "SUPER + SHIFT + 4",
                moveToWorkspace5: "SUPER + SHIFT + 5", moveToWorkspace6: "SUPER + SHIFT + 6",
                moveToWorkspace7: "SUPER + SHIFT + 7", moveToWorkspace8: "SUPER + SHIFT + 8",
                moveToWorkspace9: "SUPER + SHIFT + 9", moveToWorkspace10: "SUPER + SHIFT + 0",
                screenshotRegion: "PRINT",
                screenshotWindow: "SHIFT + PRINT",
                screenshotFull: "SUPER + PRINT",
                gameMode: "SUPER + G",
                colorPicker: "SUPER + SHIFT + C",
                clipboardHistory: "SUPER + SHIFT + V",
                filePreview: "SPACE"
            })
        }
    }

    readonly property alias general: adapter.general
    readonly property alias motion: adapter.motion
    readonly property alias typography: adapter.typography
    readonly property alias design: adapter.design
    readonly property alias language: adapter.language
    readonly property alias input: adapter.input
    readonly property alias bar: adapter.bar
    readonly property alias widgets: adapter.widgets
    readonly property alias monitors: adapter.monitors
    readonly property alias windowRules: adapter.windowRules
    readonly property alias windows: adapter.windows
    readonly property alias apps: adapter.apps
    readonly property alias launcher: adapter.launcher
    readonly property alias power: adapter.power
    readonly property alias screenshots: adapter.screenshots
    readonly property alias audio: adapter.audio
    readonly property alias network: adapter.network
    readonly property alias kdeconnect: adapter.kdeconnect
    readonly property alias accounts: adapter.accounts
    readonly property alias gaming: adapter.gaming
    readonly property alias backup: adapter.backup
    readonly property alias keybinds: adapter.keybinds
}
