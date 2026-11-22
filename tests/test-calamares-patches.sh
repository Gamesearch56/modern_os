#!/usr/bin/env bash
# Apply calamares-limit-languages.py to fixture snippets (Calamares 3.4.2).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/iso/releng/calamares-limit-languages.py"
FAIL=0
err() { printf 'test-calamares-patches: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-calamares-patches: ok %s\n' "$*"; }

[ -f "$HOOK" ] || { err "missing $HOOK"; exit 1; }

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

src="$WORKDIR/src"
mkdir -p \
    "$src/libcalamares/locale" \
    "$src/calamares" \
    "$src/modules/locale" \
    "$src/libcalamaresui/viewpages" \
    "$src/modules/keyboard" \
    "$src/modules/summary" \
    "$src/modules/partition" \
    "$src/modules/partition/gui" \
    "$src/modules/users" \
    "$src/modules/finished" \
    "$WORKDIR/lang"

python3 - "$HOOK" "$src" <<'PY'
import importlib.util
import pathlib
import sys

hook = pathlib.Path(sys.argv[1])
src = pathlib.Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("limitlang", hook)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def wrap(old: str) -> str:
    return "// fixture\n" + old + "\n// end\n"

(src / "libcalamares/locale/TranslationsModel.cpp").write_text(wrap(mod.TRANS_OLD), encoding="utf-8")
(src / "calamares/CalamaresWindow.cpp").write_text(
    wrap(mod.COMBO_INC_OLD)
    + wrap(mod.STYLE_OLD)
    + wrap(mod.SIDE_OLD)
    + wrap(mod.COMBO_INSTALL_OLD)
    + wrap(mod.QML_SIDE_OLD),
    encoding="utf-8",
)
(src / "modules/locale/LocalePage.cpp").write_text(
    wrap(mod.LOCALE_OLD) + wrap(mod.CHANGE_OLD), encoding="utf-8"
)
(src / "libcalamaresui/ViewManager.cpp").write_text(
    wrap(mod.VIEW_INC_OLD)
    + wrap(mod.VIEW_OLD)
    + wrap(mod.CANCEL_OLD)
    + wrap(mod.VIEW_CTOR_OLD)
    + wrap(mod.FOOTER_OLD),
    encoding="utf-8",
)
(src / "modules/finished/FinishedPage.h").write_text(
    wrap(mod.FINISHED_H_FWD_OLD) + wrap(mod.FINISHED_H_OLD), encoding="utf-8"
)
(src / "modules/finished/FinishedPage.cpp").write_text(
    wrap(mod.FINISHED_INC_OLD)
    + wrap(mod.FINISHED_CTOR_OLD)
    + wrap(mod.FINISHED_RETR_OLD)
    + wrap(mod.FINISHED_TEXT_OLD),
    encoding="utf-8",
)
(src / "libcalamaresui/viewpages/ExecutionViewStep.cpp").write_text(
    wrap(mod.TOGGLE_OLD), encoding="utf-8"
)
(src / "modules/keyboard/KeyboardPage.cpp").write_text(wrap(mod.KB_OLD), encoding="utf-8")
(src / "modules/keyboard/KeyboardViewStep.cpp").write_text(
    wrap(mod.KB_ACTIVATE_OLD), encoding="utf-8"
)
(src / "modules/keyboard/Config.cpp").write_text(
    wrap(mod.KB_LOCALE_INC_OLD)
    + wrap(mod.KB_APPLY_OLD)
    + wrap(mod.KB_XKB_OLD)
    + "void\nConfig::detectCurrentKeyboardLayout()\n{\n"
    + wrap(mod.KB_DETECT_OLD)
    + "}\n",
    encoding="utf-8",
)
(src / "modules/locale/Config.cpp").write_text(
    "LocaleConfiguration\nConfig::automaticLocaleConfiguration() const\n{\n"
    + wrap(mod.LOCALE_LANG_OLD)
    + "}\n",
    encoding="utf-8",
)
(src / "modules/summary/SummaryPage.cpp").write_text(
    wrap(mod.SUMMARY_CONTENT_OLD) + wrap(mod.SUMMARY_WRAP_OLD), encoding="utf-8"
)
(src / "modules/summary/Config.h").write_text(wrap(mod.SUMMARY_TITLE_OLD), encoding="utf-8")
(src / "modules/partition/PartitionViewStep.cpp").write_text(
    wrap(mod.PARTITION_SUM_OLD), encoding="utf-8"
)
(src / "modules/partition/gui/PartitionLabelsView.cpp").write_text(
    wrap(mod.PARTITION_LABELS_OLD), encoding="utf-8"
)
(src / "modules/users/UsersViewStep.cpp").write_text(wrap(mod.USERS_NAME_OLD), encoding="utf-8")
(src / "modules/users/Config.cpp").write_text(wrap(mod.USERS_CFG_OLD), encoding="utf-8")
(pathlib.Path(sys.argv[2]).parent / "lang" / "calamares_de.ts").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="de">
  <context>
    <name>UsersViewStep</name>
    <message>
      <location filename="../src/modules/users/UsersViewStep.cpp" line="48"/>
      <source>Users</source>
      <translation>Benutzer</translation>
    </message>
  </context>
  <context>
    <name>Config</name>
    <message>
      <location filename="../src/modules/summary/Config.cpp" line="35"/>
      <source>Summary</source>
      <comment>@label</comment>
      <translation>Zusammenfassung</translation>
    </message>
  </context>
  <context>
    <name>FinishedPage</name>
    <message>
      <source>&lt;h1&gt;All done.&lt;/h1&gt;&lt;br/&gt;%1 has been installed on your computer.&lt;br/&gt;You may now restart into your new system, or continue using the %2 Live environment.</source>
      <comment>@info</comment>
      <translation>&lt;h1&gt;Alles erledigt.&lt;/h1&gt;&lt;br/&gt;%1 wurde auf Ihrem Computer installiert.&lt;br/&gt;Sie können weiterhin die %2 Live-Umgebung benutzen.</translation>
    </message>
  </context>
</TS>
""",
    encoding="utf-8",
)
PY

# Same compiled-language lists as Calamares 3.4.2's CMakeLists.txt.
python3 - "$ROOT/scripts/lib" "$WORKDIR/CMakeLists.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import installer_catalog as ic

codes = " ".join(sorted(ic.CALAMARES_TRANSLATIONS - {"en"}))
with open(sys.argv[2], "w", encoding="utf-8") as f:
    f.write(f"set( _tx_complete {codes} )  # all\nset( _tx_incomplete lv mk )\n")
PY

cp "$HOOK" "$WORKDIR/calamares-limit-languages.py"
cp -a "$ROOT/iso/releng/calamares-modernnet" "$WORKDIR/calamares-modernnet"
python3 "$ROOT/scripts/installer-locales.py" --json "$WORKDIR/installer-locales.json" >/dev/null \
    || { err "installer-locales.py could not generate installer-locales.json"; exit 1; }
if ! python3 "$WORKDIR/calamares-limit-languages.py" "$WORKDIR"; then
    err "hook failed on fixture tree"
    exit 1
fi
cp -a "$src" "$WORKDIR/src-once"
cp "$WORKDIR/lang/calamares_de.ts" "$WORKDIR/de-once.ts"
if python3 "$WORKDIR/calamares-limit-languages.py" "$WORKDIR" \
    && diff -r "$WORKDIR/src-once" "$src" >/dev/null \
    && cmp -s "$WORKDIR/de-once.ts" "$WORKDIR/lang/calamares_de.ts"; then
    ok "a second hook run changes nothing (makepkg re-runs prepare)"
else
    err "hook is not idempotent: $(diff -r "$WORKDIR/src-once" "$src" | head -5)"
fi

check() {
    local file="$1" needle="$2" label="$3"
    if grep -F "$needle" "$file" >/dev/null; then
        ok "$label"
    else
        err "$label missing in $file"
    fi
}

refute() {
    local file="$1" needle="$2" label="$3"
    if grep -F "$needle" "$file" >/dev/null; then
        err "$label still in $file"
    else
        ok "$label"
    fi
}

absent() {
    local file="$1" needle="$2" label="$3"
    if grep -F "$needle" "$file" >/dev/null; then
        err "$label still in $file"
    else
        ok "$label"
    fi
}

check "$src/libcalamares/locale/TranslationsModel.cpp" 'QStringLiteral( "en" )' "en in language list"
check "$src/libcalamares/locale/TranslationsModel.cpp" 'QStringLiteral( "de" )' "de in language list"
check "$src/calamares/CalamaresWindow.cpp" "qBound( 180, 180, 180 )" "180px sidebar"
check "$src/calamares/CalamaresWindow.cpp" "qApp->setStyleSheet( ss )" "qApp stylesheet"
check "$src/calamares/CalamaresWindow.cpp" "QComboBoxPrivateContainer" "combo event filter"
check "$src/calamares/CalamaresWindow.cpp" "modernComboOverlay" "combo list overlay object name"
check "$src/calamares/CalamaresWindow.cpp" "new QListView( host )" "combo list overlay is a child of the installer window"
check "$src/calamares/CalamaresWindow.cpp" "m_combo->mapTo( host, QPoint( 0, 0 ) )" "combo list anchored to the field, not the window origin"
check "$src/calamares/CalamaresWindow.cpp" "drop ? origin.y() + m_combo->height() : qMax( 0, origin.y() - height )" "combo list flips above a field with no room below"
check "$src/calamares/CalamaresWindow.cpp" "qMin( wanted, drop ? below : above )" "combo list clamps to the space left in the window"
check "$src/calamares/CalamaresWindow.cpp" "const int width = m_combo->width();" "combo list takes the field width"
check "$src/calamares/CalamaresWindow.cpp" "qApp->installEventFilter( new ComboOverlay( qApp ) )" "combo list overlay installed application-wide"
absent "$src/calamares/CalamaresWindow.cpp" "mapToGlobal" "combo list no longer placed in screen coordinates"
check "$src/calamares/CalamaresWindow.cpp" "engine()->retranslate()" "QML sidebar retranslate"
check "$src/modules/locale/LocalePage.cpp" "new QVBoxLayout" "stacked locale"
check "$src/modules/locale/LocalePage.cpp" "m_localeChangeButton->hide()" "hide Change"
check "$src/libcalamaresui/ViewManager.cpp" "dataChanged" "ViewManager dataChanged"
check "$src/libcalamaresui/ViewManager.cpp" "quitVisible" "hide Cancel during exec"
check "$src/libcalamaresui/ViewManager.cpp" "/etc/calamares/unattended" "unattended auto-next"
check "$src/libcalamaresui/viewpages/ExecutionViewStep.cpp" 'tr( "Toggle log" )' "Toggle log tr"
check "$src/modules/keyboard/KeyboardPage.cpp" "physicalModelSelector->hide()" "hide keyboard model"
check "$src/modules/keyboard/Config.cpp" "somethingChanged();" "layout change applies with no variants"
check "$src/modules/keyboard/Config.cpp" 'QStringLiteral( "-option" ) << QString()' "setxkbmap -option with an empty value forces Xwayland remap"
check "$src/modules/keyboard/Config.cpp" "#include <QLocale>" "Welcome layout includes QLocale"
check "$src/modules/keyboard/Config.cpp" "modernWelcomeLayout" "Welcome language keyboard layout"
check "$src/modules/keyboard/Config.cpp" 'QStringLiteral( "de" )' "German Welcome layout is xkb de"
check "$src/modules/keyboard/Config.cpp" "currentLayout = welcomeLayout" "detect uses the Welcome layout"
check "$src/modules/keyboard/KeyboardViewStep.cpp" "m_config->detectCurrentKeyboardLayout();" "re-detect layout after Welcome"
check "$src/modules/locale/Config.cpp" "modernWelcomeLanguage" "Welcome language glibc locale"
check "$src/modules/locale/Config.cpp" 'QStringLiteral( "de_DE.UTF-8" )' "German Welcome locale is de_DE.UTF-8"
check "$src/modules/locale/Config.cpp" "QString lang = modernWelcomeLanguage( currentLocation() ? currentLocation()->country() : QString() );" "prefer Welcome language + timezone country over stored LANG"
check "$src/modules/locale/Config.cpp" 'QStringLiteral( "de_AT.UTF-8" )' "German in Austria installs de_AT.UTF-8"
check "$src/modules/locale/Config.cpp" 'QStringLiteral( "en_GB.UTF-8" )' "English in the UK installs en_GB.UTF-8"
check "$src/modules/keyboard/Config.cpp" 'QStringLiteral( "at" )' "German in Austria preselects the at layout"
check "$src/modules/keyboard/Config.cpp" "modernWelcomeLayout( welcomeCountry )" "keyboard layout follows the Location country"
check "$src/modules/keyboard/Config.cpp" 'readGS( *gs, QStringLiteral( "LANG" ) )' "keyboard reads the LANG the Location step stored"
check "$src/modules/summary/SummaryPage.cpp" "summaryContent" "summary content object name"
check "$src/modules/partition/PartitionViewStep.cpp" "summaryPartition" "partition summary object name"
check "$src/modules/partition/gui/PartitionLabelsView.cpp" "QPalette::WindowText" "partition legend palette text"
check "$src/modules/users/UsersViewStep.cpp" 'tr( "User" )' "Users step prettyName"
check "$src/modules/users/Config.cpp" 'setLoginName( QStringLiteral( "modern" ) )' "unattended login"
check "$WORKDIR/lang/calamares_de.ts" "<source>User</source>" "Users step German source"
check "$WORKDIR/lang/calamares_de.ts" "<source>Summary</source>" "Summary English source kept in German ts"
check "$WORKDIR/lang/calamares_de.ts" "<translation>Übersicht</translation>" "Summary step German title"
check "$src/modules/summary/Config.h" 'tr( "Summary", "@label" )' "Summary title live tr"
check "$src/modules/modernnet/CMakeLists.txt" "calamares_add_plugin(modernnet" "modernnet plugin cmake"
check "$src/modules/modernnet/CMakeLists.txt" "ModernNetRow.cpp" "modernnet wifi row source"
check "$src/modules/modernnet/ModernNetViewStep.cpp" 'tr( "Network", "@title" )' "Network step prettyName"
check "$src/modules/modernnet/ModernNetPage.cpp" "You're connected with Wi-Fi" "Network step Wi-Fi success copy"
check "$src/modules/modernnet/ModernNetPage.cpp" "m_okHint->setText" "Network step hint retranslates on show"
check "$WORKDIR/lang/calamares_de.ts" "Du kannst mit dem nächsten Schritt fortfahren." "Network step German continue hint"
check "$src/modules/modernnet/ModernNetRow.cpp" "Password required" "Network step lock label"
check "$WORKDIR/lang/calamares_de.ts" "<translation>Netzwerk</translation>" "Network step German title"
check "$WORKDIR/lang/calamares_de.ts" "<translation>Du bist per WLAN verbunden</translation>" "Network step German Wi-Fi success"
check "$src/modules/finished/FinishedPage.cpp" "finishedBadge" "finished badge object name"
check "$src/modules/finished/FinishedPage.cpp" "finishedMainText" "finished main text object name"
check "$src/modules/finished/FinishedPage.cpp" "finishedRestart" "finished restart button object name"
check "$src/modules/finished/FinishedPage.cpp" "QCoreApplication::quit()" "restart button quits to trigger doRestart"
check "$src/modules/finished/FinishedPage.h" "m_restartButton" "FinishedPage restart member"
check "$src/libcalamaresui/ViewManager.cpp" "updateBackAndNextVisibility( false )" "footer hidden on the finished page"
check "$src/modules/finished/FinishedPage.cpp" "%1 is installed and ready." "finished English success copy"
check "$WORKDIR/lang/calamares_de.ts" "ist installiert und einsatzbereit." "finished German success copy"
refute "$src/modules/finished/FinishedPage.cpp" "Live environment" "English success copy names no live medium"
if python3 - "$WORKDIR/lang/calamares_de.ts" "$src/modules/finished/FinishedPage.cpp" <<'PY'
import re, sys
import xml.etree.ElementTree as ET

cpp = open(sys.argv[2], encoding="utf-8").read()
call = re.search(r'setText\( tr\( ((?:"(?:[^"\\]|\\.)*"\s*)+),\s*"@info"', cpp)
source = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', call.group(1)))
hits = [
    m.findtext("translation") or ""
    for m in ET.parse(sys.argv[1]).getroot().iter("message")
    if m.findtext("source") == source and m.findtext("comment") == "@info"
]
sys.exit(0 if hits and all(h and "Live" not in h for h in hits) else 1)
PY
then
    ok "German success copy the finished page uses names no live medium"
else
    err "German translation of the current finished copy is missing or names the live medium"
fi

if grep -F 'UPDATE_BUTTON_PROPERTY( quitVisible, true );' "$src/libcalamaresui/ViewManager.cpp" >/dev/null; then
    err "Done button still shown at the very end"
else
    ok "Done button hidden at the very end"
fi

# "ModernOS-Live" was never spelled out in source: it was a branding name
# pasted into a placeholder next to "Live". Grepping the literals cannot see
# that, so render the copy with every name branding.desc can supply.
if python3 - "$HOOK" "$ROOT/iso/airootfs/etc/calamares/branding/modern/branding.desc" <<'PY'
import importlib.util
import pathlib
import re
import sys

spec = importlib.util.spec_from_file_location("limitlang", pathlib.Path(sys.argv[1]))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

names = re.findall(
    r"^\s+\w*Name:\s*(\S+)", pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"), re.M
)
if not names:
    sys.exit("no branding names in branding.desc")
sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parents[2] / "scripts/lib"))
import installer_catalog as ic
tdir = pathlib.Path(sys.argv[1]).parents[2] / "stow/modern/.config/modern/translations"
copy = mod.FINISHED_TEXT_NEW + "".join(
    t.get("installer.finished.done", "") for t in ic.load_translations(tdir.parent).values()
)
leaks = sorted(
    {
        name + sep + "Live"
        for name in names
        for sep in ("-", " ")
        if name + sep + "Live" in re.sub(r"%[0-9]", name, copy)
    }
)
sys.exit("; ".join(leaks) if leaks else 0)
PY
then
    ok "finished success copy renders no live-medium name"
else
    err "finished success copy renders a live-medium name"
fi

# A language Calamares does not compile would show in Welcome and then
# leave every page English. The build has to stop with the reason instead.
python3 - "$WORKDIR/installer-locales.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
data["locales"].append(dict(data["locales"][0], calamares="lv"))
json.dump(data, open(sys.argv[1], "w", encoding="utf-8"))
PY
rm -rf "$src" && cp -a "$WORKDIR/src-once" "$src"
if out="$(python3 "$WORKDIR/calamares-limit-languages.py" "$WORKDIR" 2>&1)"; then
    err "hook accepted a language Calamares does not compile"
elif grep -F "does not compile translations ['lv']" <<<"$out" >/dev/null; then
    ok "hook stops the build for a language Calamares does not compile"
else
    err "uncompiled language failed without a clear reason: $out"
fi

[ "$FAIL" -eq 0 ]
