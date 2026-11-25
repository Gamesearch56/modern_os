// Reactive, read-only view of ~/.config/modern/config.json — see
// docs/ARCHITECTURE.md's "Config layer" and docs/DECISIONS.md #3 (the
// Settings app is the only writer; this singleton never calls
// writeAdapter(), matching stow/hypr/.config/hypr/modules/config.lua's
// same read-only stance on the Hyprland side).
//
// Every property below mirrors stow/modern/.config/modern/config.default.json
// 1:1 — that file is the authoritative schema; this is its QML-typed
// reflection. Typed JsonObject sections get QML fallbacks; `var` blobs
// (keybinds, widgets, windowRules, monitors, …) are replaced wholesale
// by the live JSON object and are not deep-merged. Restore missing keys
// from config.default.json after a shipped-key add. Promote a `var`
// section to a typed JsonObject when a consumer needs granular
// reactivity on one of its keys.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property int _configMisses: 0
    // Bumped on every successful load so Services can react when nested
    // JsonObject ints (idleTimings) do not emit their own changed signals.
    property int generation: 0
    // False until config.json was read once (or could not be). Until then
    // every value is a QML fallback, so chrome that depends on a saved
    // choice, like auto-hide, waits for this before it shows.
    property bool loaded: false

    FileView {
        id: file
        path: `${root.home}/.config/modern/config.json`
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            root._configMisses = 0
            root.generation++
            root.loaded = true
        }
        onLoadFailed: (error) => {
            // FileNotFound (2): atomic replace can fire the watcher between
            // unlink and rename. Retry; do not toast.
            if (error === FileViewError.FileNotFound && root._configMisses < 8) {
                root._configMisses++;
                Qt.callLater(() => file.reload());
                return;
            }
            Logger.error("Config", "failed to load config.json: " + error);
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property JsonObject general: JsonObject {
                property list<string> autostart: ["proton-mail.desktop", "proton-calendar.desktop", "whatsapp.desktop"]
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
                property string sourceSeed: ""
                property real cornerRounding: 1.0
                property real transparency: 0.85
                property real surfaceTint: 0.7
                property int blurStrength: 40
                property string iconTheme: "Papirus-Dark"
                property string cursorTheme: "Bibata-Modern-Classic"
                property int cursorSize: 24
                property string wallpaperProvider: "https://4kwallpapers.com"
                property string wallpaperTransition: "fade"
                property JsonObject bootScreen: JsonObject {
                    property string mode: "static"
                    property bool wallpaperOnSplash: true
                    property bool wallpaperOnLock: true
                    property bool wallpaperOnLogin: true
                    property bool wallpaperOnVivaldi: true
                }
            }

            property JsonObject language: JsonObject {
                property string ui: "en" // JSON key "ui", not "interface" — reserved QML identifier, see docs/DECISIONS.md
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

            // Edge is not stored. DockLayout mirrors the bar.
            property JsonObject dock: JsonObject {
                property bool enabled: true
                property bool autoHide: false
                property int iconSize: 48
                property bool showNames: false
                property int pad: 8
                property int gap: 8
                property string theme: "floating"
                property string hover: "zoom"
                property list<string> apps: [
                    "vivaldi-stable", "whatsapp", "spotify-launcher", "steam",
                    "kitty", "shell:files", "modern.manual", "shell:store", "shell:settings"
                ]
            }

            // Per-widget settings blobs — shape varies per widget, each
            // widget reads its own key (e.g. Config.widgets.clock).
            property var widgets: ({
                clock: { dateFormat: "DD.MM.YYYY", timeFormat: "HH:mm", showSeconds: false, showWeekday: false, calendarProvider: "none", calendarAccount: "" },
                weather: { locationMode: "auto", manualLocation: "", placeName: "", units: "metric", pollIntervalMs: 600000 },
                performance: { pollIntervalMs: 2000, showGpu: true, showTemps: true },
                audio: { scrollStepPercent: 5, scrollStepFinePercent: 1 }
            })

            // Per-monitor profiles (keyed by "description + serial") and
            // workspace-assignment rules — see docs/ARCHITECTURE.md
            // "Monitors". Free-form since the key set is per-machine.
            property var monitors: ({ profiles: ({}), rules: [], workspaceMode: "dynamic", primaryDescription: "" })

            property var windowRules: [
                {
                    name: "jetbrains-dialogs",
                    match: { class: "jetbrains-.*", title: "win0" },
                    float: true
                }
            ]

            property JsonObject gaming: JsonObject {
                property bool mode: false
                property bool autoFullscreen: true
                property bool autoOptimize: false
                property bool hdrSession: false
                property bool browserLight: false
                property string matchClass: "steam_app_.*|gamescope|.*\\.exe|ProjectZomboid.*|projectzomboid|LWJGL|lwjgl|wow|Wow|Warcraft.*"
                property string matchTitle: ".*\\.exe|Project Zomboid|World of Warcraft|Warcraft III|Warcraft 3|Diablo.*|Overwatch.*|Hearthstone|StarCraft.*|Call of Duty.*"
            }

            property JsonObject windows: JsonObject {
                property real opacity: 1.0
                property int gapsIn: 5
                property int gapsOut: 10
            }

            property JsonObject apps: JsonObject {
                property JsonObject defaults: JsonObject {
                    property string browser: "vivaldi-stable.desktop"
                    property string calendar: "proton-calendar.desktop"
                    property string mail: "proton-mail.desktop"
                    property string communication: "whatsapp.desktop"
                    property string fileManager: "modern.files.desktop"
                    // These three match install/manifests/default-apps.json.
                    // test-default-apps.sh rejects drift. Packages and launch
                    // overrides live in that manifest, not here.
                    property string videoPlayer: "modern.mediaplayer.desktop"
                    property string imageViewer: "modern.imageviewer.desktop"
                    property string textEditor: "modern.editor.desktop"
                    property string terminal: "kitty.desktop"
                }
            }

            property JsonObject input: JsonObject {
                property string kbLayout: "us"
                property string kbVariant: ""
                property int repeatRate: 25
                property int repeatDelay: 600
                property bool numlockOnBoot: false
                property bool mouseSideButtons: true
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
                property string videoDirectory: "~/Videos/Recordings"
                property string videoFilenameTemplate: "recording-%Y%m%d-%H%M%S"
                property bool recordAudio: true
            }

            property JsonObject audio: JsonObject {
                property string autoSwitchBluetooth: "on"
                property string fallbackSink: ""
                property string fallbackSource: ""
                property string lastSink: ""
                property string lastSource: ""
                property var perAppVolume: ({})
                property int masterVolume: -1
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
                ai: { provider: "none", ollamaModel: "llama3", geminiModel: "", chatgptModel: "", thinking: false, brief: true }
            })

            property JsonObject census: JsonObject {
                property bool enabled: false
                property string url: ""
            }

            property JsonObject bugReport: JsonObject {
                property string repo: "Gamesearch56/modern-reports"
                property bool screenshotsDefault: true
            }

            property JsonObject files: JsonObject {
                property string sortKey: "name"
                property bool sortDesc: true
                property bool foldersFirst: true
                property string view: "grid"
                property bool showHidden: false
                property bool showSize: true
                property bool showCreated: true
                property bool showModified: true
                property bool showType: true
                property bool showRecent: true
                property bool showNetwork: false
                property var favorites: []
            }

            property JsonObject editor: JsonObject {
                property bool wordWrap: true
                property bool statusBar: true
                property bool monospace: true
                property int zoom: 100
                property int maxMegabytes: 8
            }

            property JsonObject viewer: JsonObject {
                property string scaling: "shrink"
                property bool info: false
                property int slideshowSeconds: 4
            }

            property JsonObject player: JsonObject {
                property real volume: 1
                property bool muted: true
                property bool loop: true
                property int seekSeconds: 5
                property int jumpSeconds: 60
            }

            property JsonObject backup: JsonObject {
                property bool snapperEnabled: false
                property bool resticEnabled: false
                property bool preUpdateSnapshot: true
                property bool pruneEnabled: true
                property int keepCount: 8
            }

            // Combo strings use Hyprland's Lua hl.bind() format:
            // "MOD + MOD + KEY" — see config.default.json's own
            // "_comment" key and Modules/Cheatsheet, which reads this
            // same object to render the SUPER+K overlay.
            property var keybinds: ({
                launcher: "SUPER + SPACE",
                aiChat: "SUPER + A",
                powerMenu: "SUPER + M",
                controlCenter: "SUPER + N",
                lockScreen: "SUPER + L",
                exitSession: "SUPER + SHIFT + M",
                cheatsheet: "SUPER + K",
                settings: "SUPER + I",
                wallpaperPicker: "SUPER + W",
                taskbar: "SUPER + DELETE",
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
                colorPicker: "SUPER + SHIFT + C",
                manual: "SUPER + Y",
                filePreview: "SPACE",
                bugReport: "SUPER + #"
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
    readonly property alias dock: adapter.dock
    readonly property alias widgets: adapter.widgets
    readonly property alias monitors: adapter.monitors
    readonly property alias windowRules: adapter.windowRules
    readonly property alias gaming: adapter.gaming
    readonly property alias windows: adapter.windows
    readonly property alias apps: adapter.apps
    readonly property alias launcher: adapter.launcher
    readonly property alias power: adapter.power
    readonly property alias screenshots: adapter.screenshots
    readonly property alias audio: adapter.audio
    readonly property alias network: adapter.network
    readonly property alias kdeconnect: adapter.kdeconnect
    readonly property alias accounts: adapter.accounts
    readonly property alias backup: adapter.backup
    readonly property alias keybinds: adapter.keybinds
    readonly property alias bugReport: adapter.bugReport
    readonly property alias census: adapter.census
    readonly property alias files: adapter.files
    readonly property alias editor: adapter.editor
    readonly property alias viewer: adapter.viewer
    readonly property alias player: adapter.player
}
