# ModernOS Manual

This page is for developers: how the documentation reader works and how to add to the documentation. The user-facing description of the app is in [Apps](manual/09-apps.md).

The Manual opens with **SUPER + Y** (`keybinds.manual`) or from the launcher. Its desktop entry is `modern.manual.desktop` (Name "ModernOS Manual"). The launcher, dock and Overview show the short name "Manual" through `Commons/ModernApps.qml`.

## Behaviour

- On the left is a search field and every document, in two parts: **User manual** (`docs/manual/`, numbered, in file-name order) and **Technical reference** (`README.md`, `CONTRIBUTING.md` and `docs/*.md`). Each part is split into sections; `MANUAL_SECTIONS` and `REFERENCE_SECTIONS` in `scripts/manual-index.py` say which file goes where and in what order. A file in neither table lands in **More** (Weitere). On the right is the open document.
- Search matches every word of the query against the title and the full text.
- A link to another `.md` file resolves against the folder of the document it is in and opens inside the window. Back (title bar, Alt + Left, Backspace, the mouse back button) retraces those steps and Forward (title bar, Alt + Right, the mouse forward button) replays them. Opening a new document clears Forward. `http`, `https` and `mailto` links open through `xdg-open`. Links to anything else (source files, bare `#anchors`) do nothing.
- Text can be selected and copied. Arrow keys, Page Up/Down, Space, Home and End scroll the document; Ctrl + F jumps to the search field.
- Accessibility: Tab / Shift + Tab select the next / previous link that goes somewhere (the web or another `.md`), Enter follows it, and Tab past the last link moves focus on. Ctrl + Plus/Minus/0 and Ctrl + wheel zoom the text (50–300 %, per window). The list, its headings and the document carry `Accessible` roles and names.
- There is one window. SUPER + Y while it is open focuses it. `modern-manual FILE.md` opens a new window on that document.
- A normal tiled window (class `modern.manual`). It isn't listed in `windows.lua`.

## Pieces

| File | Role |
|---|---|
| `scripts/modern-manual` | The launcher. It focuses an open window, or starts `qs -p manual.qml` with `MODERN_MANUAL_DOC`. `MODERN_MANUAL_DRY=1` prints instead of running. |
| `stow/shell/.config/quickshell/modern/manual.qml` | Root (`//@ pragma AppId modern.manual`). File watching is off, so a reload can't drop the open document. |
| `scripts/manual-index.py` | Prints every document as JSON: `path`, `rel`, `group`, `title` (the first `# ` heading), `text` and `html`. |
| `scripts/lib/manual_markdown.py` | Markdown to Qt rich text. It leaves colors, sizes and fonts as `{{name}}` placeholders. |
| `Services/ManualDocs.qml` | Runs the index once, searches it, and opens web links. |
| `Modules/Manual/Module.qml` | The current document, the Back history, and link following (`links.js`). |
| `Modules/Manual/Nav.qml`, `NavRow.qml`, `Reader.qml`, `ManualWindow.qml` | The list and its rows (part and section headings, numbered chapters), the reading pane (fills the placeholders from `Colors`, `Typography` and `Tokens`), and the window. |

## Writing documentation

The renderer supports ATX headings (`#` to `####`), paragraphs, nested bullet and numbered lists, fenced code blocks, GitHub tables, block quotes, horizontal rules, links, `inline code`, **bold** and *italic*. For the README it also takes the HTML GitHub shows (`div`, `p`, `br`, `table`, `tr`, `td`, `th`, `img`, `center`, with only `align`, `width`, `src` and `alt`; `scripts/lib/manual_html.py`), local pictures, and badges: `[![alt](badge)](url)` becomes a link named by its alt text, and a web picture shows its alt text, since the window never loads from the network. Any other tag stays visible as text. Footnotes and diagrams are not supported: a `mermaid` block shows as plain code.

- Start every file with one `# Title` line. The list and the window title use it.
- A new user-manual chapter is a new `docs/manual/NN-name.md`. The number sets its place in the list; add it to a section in `MANUAL_SECTIONS` and keep the numbers counting up through the sections. Link to it from `docs/manual/01-welcome.md`. A new reference document goes into `REFERENCE_SECTIONS`; `tests/test-manual.py` fails while a document has no section.
- User-manual chapters are for everyday users. Name UI elements by their English label, then the German label in parentheses the first time. Don't name QML files, Services or config keys there; those belong in the technical reference.
- Link between documents with relative paths: `[Settings](07-settings.md)` inside `docs/manual/`, `[Theming](../THEMING.md)` from there into the reference.

`tests/test-manual.sh` checks the launcher, the desktop entry, the keybind, and the renderer. It also checks that every relative link in the docs points at a file that exists.

On an installed system the documents are read from the ModernOS checkout (`Paths.repo`, normally `~/modern_dotfile`), so an update of the desktop updates the manual too. The ISO installs a sparse checkout; `docs` must stay in its cone (`scripts/iso-build.sh`), and `scripts/desktop-sync.sh` adds it to checkouts from ISOs up to v0.7.5 that left it out.
