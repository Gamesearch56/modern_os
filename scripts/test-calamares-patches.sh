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
    wrap(mod.FINISHED_INC_OLD) + wrap(mod.FINISHED_CTOR_OLD) + wrap(mod.FINISHED_RETR_OLD),
    encoding="utf-8",
)
(src / "libcalamaresui/viewpages/ExecutionViewStep.cpp").write_text(
    wrap(mod.TOGGLE_OLD), encoding="utf-8"
)
(src / "modules/keyboard/KeyboardPage.cpp").write_text(wrap(mod.KB_OLD), encoding="utf-8")
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
    wrap(mod.USERS_TS_OLD) + wrap(mod.SUMMARY_TS_OLD), encoding="utf-8"
)
PY

cp "$HOOK" "$WORKDIR/calamares-limit-languages.py"
cp "$ROOT/iso/releng/installer-locales.json" "$WORKDIR/installer-locales.json"
cp -a "$ROOT/iso/releng/calamares-modernnet" "$WORKDIR/calamares-modernnet"
if ! python3 "$WORKDIR/calamares-limit-languages.py" "$WORKDIR"; then
    err "hook failed on fixture tree"
    exit 1
fi

check() {
    local file="$1" needle="$2" label="$3"
    if grep -F "$needle" "$file" >/dev/null; then
        ok "$label"
    else
        err "$label missing in $file"
    fi
}

check "$src/libcalamares/locale/TranslationsModel.cpp" 'QStringLiteral( "en" )' "en in language list"
check "$src/libcalamares/locale/TranslationsModel.cpp" 'QStringLiteral( "de" )' "de in language list"
check "$src/calamares/CalamaresWindow.cpp" "qBound( 180, 180, 180 )" "180px sidebar"
check "$src/calamares/CalamaresWindow.cpp" "qApp->setStyleSheet( ss )" "qApp stylesheet"
check "$src/calamares/CalamaresWindow.cpp" "QComboBoxPrivateContainer" "combo event filter"
check "$src/calamares/CalamaresWindow.cpp" "mapToGlobal" "combo mapToGlobal"
check "$src/calamares/CalamaresWindow.cpp" "modernRemapping" "combo hide/show remap"
check "$src/calamares/CalamaresWindow.cpp" "engine()->retranslate()" "QML sidebar retranslate"
check "$src/modules/locale/LocalePage.cpp" "new QVBoxLayout" "stacked locale"
check "$src/modules/locale/LocalePage.cpp" "m_localeChangeButton->hide()" "hide Change"
check "$src/libcalamaresui/ViewManager.cpp" "dataChanged" "ViewManager dataChanged"
check "$src/libcalamaresui/ViewManager.cpp" "quitVisible" "hide Cancel during exec"
check "$src/libcalamaresui/ViewManager.cpp" "/etc/calamares/unattended" "unattended auto-next"
check "$src/libcalamaresui/viewpages/ExecutionViewStep.cpp" 'tr( "Toggle log" )' "Toggle log tr"
check "$src/modules/keyboard/KeyboardPage.cpp" "physicalModelSelector->hide()" "hide keyboard model"
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
check "$src/modules/modernnet/ModernNetViewStep.cpp" 'tr( "Network", "@title" )' "Network step prettyName"
check "$WORKDIR/lang/calamares_de.ts" "<translation>Netzwerk</translation>" "Network step German title"
check "$src/modules/finished/FinishedPage.cpp" "finishedBadge" "finished badge object name"
check "$src/modules/finished/FinishedPage.cpp" "finishedMainText" "finished main text object name"
check "$src/modules/finished/FinishedPage.cpp" "finishedRestart" "finished restart button object name"
check "$src/modules/finished/FinishedPage.cpp" "QCoreApplication::quit()" "restart button quits to trigger doRestart"
check "$src/modules/finished/FinishedPage.h" "m_restartButton" "FinishedPage restart member"
check "$src/libcalamaresui/ViewManager.cpp" "updateBackAndNextVisibility( false )" "footer hidden on the finished page"

if grep -F 'UPDATE_BUTTON_PROPERTY( quitVisible, true );' "$src/libcalamaresui/ViewManager.cpp" >/dev/null; then
    err "Done button still shown at the very end"
else
    ok "Done button hidden at the very end"
fi

[ "$FAIL" -eq 0 ]
