#!/usr/bin/env bash
# Build Phylax with the session user preselected and the identity
# dropdown hidden. Installs to ~/.local/bin/phylax; phylax.service
# prefers that over /usr/bin.
# Upstream recreates the DropDown model on every Relm4 watch, so the
# selected admin resets to the first uid and cannot be changed.
set -euo pipefail

SRC="${XDG_CACHE_HOME:-$HOME/.cache}/modern/phylax-src"
BIN="$HOME/.local/bin/phylax"
mkdir -p "$(dirname "$SRC")" "$(dirname "$BIN")"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 https://github.com/jakeb-grant/phylax.git "$SRC"
else
    git -C "$SRC" fetch --depth 1 origin
    git -C "$SRC" reset --hard origin/HEAD
fi

python3 - "$SRC/src/ui.rs" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
t = p.read_text()

old_vis = 'add_css_class: "auth-identity-box",\n                    set_baseline_position:'
new_vis = 'add_css_class: "auth-identity-box",\n                    set_visible: false,\n                    set_baseline_position:'
if old_vis not in t:
    sys.exit("phylax ui.rs identity box did not match; update scripts/build-phylax.sh")
t = t.replace(old_vis, new_vis, 1)

old_btn = '''                    append = &gtk::Button::with_label("Confirm") {
                        add_css_class: "auth-confirm",
                        connect_clicked[sender, identity_dropdown, password_entry] => move |_| {
                            if let Some(item) = identity_dropdown.selected_item() {
                                let user: gtk::StringObject = item.dynamic_cast().unwrap();
                                sender.input(AppMsg::Confirm { user: user.string().to_string(), password: password_entry.text().to_string()});
                                password_entry.set_text("");
                            }
                        }
                    }'''
new_btn = '''                    append = &gtk::Button::with_label("Confirm") {
                        add_css_class: "suggested-action",
                        add_css_class: "auth-confirm",
                        connect_clicked[sender, identity_dropdown, password_entry] => move |_| {
                            let selected = identity_dropdown
                                .selected_item()
                                .and_then(|item| item.dynamic_cast::<gtk::StringObject>().ok())
                                .map(|u| u.string().to_string());
                            let user = std::env::var("USER")
                                .ok()
                                .filter(|me| !me.is_empty())
                                .or(selected)
                                .unwrap_or_default();
                            if user.is_empty() {
                                return;
                            }
                            sender.input(AppMsg::Confirm { user, password: password_entry.text().to_string()});
                            password_entry.set_text("");
                        }
                    }'''
if old_btn not in t:
    sys.exit("phylax ui.rs confirm button did not match; update scripts/build-phylax.sh")
t = t.replace(old_btn, new_btn, 1)

old_names = "                        self.identities = names.clone();"
new_names = '''                        let mut names = names.clone();
                        if let Ok(me) = std::env::var("USER") {
                            if let Some(i) = names.iter().position(|n| n == &me) {
                                names.remove(i);
                                names.insert(0, me);
                            }
                        }
                        self.identities = names;'''
if old_names not in t:
    sys.exit("phylax ui.rs Started identities did not match; update scripts/build-phylax.sh")
t = t.replace(old_names, new_names, 1)

p.write_text(t)
print("patched", p)
PY

unset CARGO_TARGET_DIR
(cd "$SRC" && cargo +stable build --release)
install -m 755 "$SRC/target/release/phylax" "$BIN"
printf 'installed %s\n' "$BIN"
