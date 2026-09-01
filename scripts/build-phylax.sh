#!/usr/bin/env bash
# Build Phylax with the session user preselected, the identity
# dropdown hidden, and arrow/Enter keyboard navigation. Installs to
# ~/.local/bin/phylax; phylax.service prefers that over /usr/bin.
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

old_dd = '''                    gtk::DropDown {
                        add_css_class: "auth-identity",
                        set_margin_bottom: 8,'''
new_dd = '''                    gtk::DropDown {
                        add_css_class: "auth-identity",
                        set_can_focus: false,
                        set_margin_bottom: 8,'''
if old_dd not in t:
    sys.exit("phylax ui.rs identity dropdown did not match; update scripts/build-phylax.sh")
t = t.replace(old_dd, new_dd, 1)

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

old_auth = '''                    self.retry_message = Some("Authenticating...".to_string());
                    self.authenticating = true;'''
new_auth = '''                    self.retry_message = None;
                    self.authenticating = true;'''
if old_auth not in t:
    sys.exit("phylax ui.rs Authenticating label did not match; update scripts/build-phylax.sh")
t = t.replace(old_auth, new_auth, 1)

old_show = '''            connect_show[password_entry, css_path] => move |_| {
                let _ = relm4::set_global_css_from_file(&css_path);
                password_entry.grab_focus();
            },
            connect_close_request[cancel_button] => move |_| {
                cancel_button.emit_clicked();
                gtk4::glib::Propagation::Proceed
            },
'''
new_show = '''            connect_show[password_entry, confirm_button, css_path] => move |win| {
                let _ = relm4::set_global_css_from_file(&css_path);
                win.present();
                win.set_focus_visible(true);
                win.set_default_widget(Some(&confirm_button));
                let mut child = password_entry.first_child();
                while let Some(c) = child {
                    let next = c.next_sibling();
                    if c.downcast_ref::<gtk::Button>().is_some() {
                        c.set_can_focus(false);
                    }
                    child = next;
                }
                gtk4::prelude::GtkWindowExt::set_focus(win, Some(&password_entry));
                password_entry.grab_focus();
                let entry = password_entry.clone();
                let window = win.clone();
                gtk4::glib::timeout_add_local_once(std::time::Duration::from_millis(80), move || {
                    window.present();
                    gtk4::prelude::GtkWindowExt::set_focus(&window, Some(&entry));
                    entry.grab_focus();
                });
            },
            connect_close_request[cancel_button] => move |_| {
                cancel_button.emit_clicked();
                gtk4::glib::Propagation::Proceed
            },
            add_controller = gtk::EventControllerKey {
                set_propagation_phase: gtk::PropagationPhase::Capture,
                connect_key_pressed[password_entry, cancel_button, confirm_button] => move |_, key, _, mods| {
                    let focused = password_entry.root().and_then(|r| r.focus());
                    let in_host = |host: &gtk::Widget| -> bool {
                        match &focused {
                            Some(f) => f == host || f.is_ancestor(host) || host.is_ancestor(f),
                            None => false,
                        }
                    };
                    let cancel = in_host(cancel_button.upcast_ref());
                    let confirm = in_host(confirm_button.upcast_ref());
                    let pass = !cancel && !confirm;
                    let shift = mods.contains(gtk::gdk::ModifierType::SHIFT_MASK);
                    let tab = key == gtk::gdk::Key::Tab || key == gtk::gdk::Key::ISO_Left_Tab;
                    let up = key == gtk::gdk::Key::Up || key == gtk::gdk::Key::KP_Up;
                    let down = key == gtk::gdk::Key::Down || key == gtk::gdk::Key::KP_Down;
                    let left = key == gtk::gdk::Key::Left || key == gtk::gdk::Key::KP_Left;
                    let right = key == gtk::gdk::Key::Right || key == gtk::gdk::Key::KP_Right;
                    if key == gtk::gdk::Key::Escape {
                        cancel_button.emit_clicked();
                        return gtk4::glib::Propagation::Stop;
                    }
                    if key == gtk::gdk::Key::Return || key == gtk::gdk::Key::KP_Enter {
                        if cancel {
                            cancel_button.emit_clicked();
                        } else {
                            confirm_button.emit_clicked();
                        }
                        return gtk4::glib::Propagation::Stop;
                    }
                    if tab {
                        if shift || key == gtk::gdk::Key::ISO_Left_Tab {
                            if confirm {
                                cancel_button.grab_focus();
                            } else if cancel {
                                password_entry.grab_focus();
                            } else {
                                confirm_button.grab_focus();
                            }
                        } else if confirm {
                            password_entry.grab_focus();
                        } else if cancel {
                            confirm_button.grab_focus();
                        } else {
                            cancel_button.grab_focus();
                        }
                        return gtk4::glib::Propagation::Stop;
                    }
                    if down && pass {
                        cancel_button.grab_focus();
                        return gtk4::glib::Propagation::Stop;
                    }
                    if up && (cancel || confirm) {
                        password_entry.grab_focus();
                        return gtk4::glib::Propagation::Stop;
                    }
                    if right && cancel {
                        confirm_button.grab_focus();
                        return gtk4::glib::Propagation::Stop;
                    }
                    if left && confirm {
                        cancel_button.grab_focus();
                        return gtk4::glib::Propagation::Stop;
                    }
                    gtk4::glib::Propagation::Proceed
                }
            },
'''
if old_show not in t:
    sys.exit("phylax ui.rs show/focus did not match; update scripts/build-phylax.sh")
t = t.replace(old_show, new_show, 1)

old_flow = '''                gtk::FlowBox {
                    add_css_class: "auth-buttons",
                    set_hexpand: true,
                    set_homogeneous: true,
                    set_margin_bottom: 16,
                    set_margin_top: 8,
                    set_max_children_per_line: 2,
                    set_valign: gtk::Align::End,
                    set_vexpand: true,
'''
new_flow = '''                gtk::Box {
                    add_css_class: "auth-buttons",
                    set_orientation: gtk::Orientation::Horizontal,
                    set_hexpand: true,
                    set_homogeneous: true,
                    set_can_focus: false,
                    set_margin_bottom: 16,
                    set_margin_top: 8,
                    set_valign: gtk::Align::End,
                    set_vexpand: true,
'''
if old_flow not in t:
    sys.exit("phylax ui.rs button row did not match; update scripts/build-phylax.sh")
t = t.replace(old_flow, new_flow, 1)


p.write_text(t)
print("patched", p)
PY

unset CARGO_TARGET_DIR
(cd "$SRC" && cargo +stable build --release)
install -m 755 "$SRC/target/release/phylax" "$BIN"
printf 'installed %s\n' "$BIN"
