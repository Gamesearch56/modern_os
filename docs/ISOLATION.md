# Isolation: keeping the current user safe

`modern_dotfile` is built and iterated on while `bastianweigand` remains the
daily-driver account on this machine. Nothing here may break that account
until you explicitly decide the new system is ready and run the gated
system-wide phase yourself.

How to create `devuser`, start Hyprland on a second TTY, and return to
this session: **`README.md`**. Install flags: `docs/INSTALL.md`.

## Safe by construction

- All development lives in this repo, at
  `/home/bastianweigand/CursorProjects/modern_dotfile`. Nothing is ever
  written to `~/.config/`, `~/.local/`, `~/dotfiles/` or `~/.bashrc` for the
  `bastianweigand` account by this project's default commands.
- `install.sh` **refuses** a stow target of `/home/bastianweigand` (or any
  path under it). Override with `MODERN_PROTECT_HOME` if the protected
  path differs; override the refuse with `--allow-live-home` only for a
  deliberate cutover (new PC that reuses this username).
- `stow` therefore never runs against the daily-driver home during testing.
  Conflict backups are stored under `$TARGET/.local/state/modern/stow-backups`.
- All runtime state this project creates lives under the **target** user's
  home or the new `/var/lib/modern/` path — nothing pre-existing reads either.
- `~/dotfiles` (the old repo) is read-only reference material. It is never
  committed to, never modified, from this repo or its scripts.
- Creating the `devuser` **account** is the intended test path. It does not
  change autologin, greetd, or `/etc`. Isolation check treats that account
  as OK, not as a leak.

## Switching sessions without touching the main user

1. Leave the `bastianweigand` Hyprland session running.
2. `Ctrl+Alt+F3`, log in as `devuser`, run `start-hyprland`
   (not the `Hyprland` binary). One Hyprland per user — exit the old
   one before starting another TTY.
3. Return with `Ctrl+Alt+F1` or `F2`. End the test compositor with
   `hyprctl dispatch "hl.dsp.exit()"`, then `exit` on the TTY.

A reboot still autologins the daily-driver account as long as greetd was
never enabled. Removing the test account (`sudo userdel -r devuser`)
deletes `/home/devuser` only.

## Gated: system-wide changes

These affect the whole machine, not one account, so they are **staged as
files under `install/system/` and never applied automatically**. Applying
them is a separate, explicit, human-invoked step — see each file's header
comment for the exact command.

| Change | Why it's gated | Rollback |
|---|---|---|
| `greetd` enablement | Replaces autologin machine-wide. A broken greeter locks out *both* users graphically. | `sudo systemctl disable greetd`, re-enable the previous getty autologin unit, reboot. Documented in the file header of `install/system/greetd/config.toml` (when that file lands). |
| Plymouth theme + `mkinitcpio` hooks | Rewrites the initramfs. A bad rebuild can leave the machine unable to boot. | `sudo mkinitcpio -P` after reverting `/etc/mkinitcpio.conf`; the previous initramfs stays as a fallback boot entry — never delete it. |
| `sysctl.d`, `polkit` actions, `tmpfiles.d`, udev rules, gaming perf sysctls | System-wide kernel/session policy. | Remove the dropped-in file under `/etc/{sysctl.d,polkit-1,tmpfiles.d,udev/rules.d}/modern-*` and reload (`sysctl --system`, `systemctl restart polkit`, `systemd-tmpfiles --create`). |
| `modern-usersd` + its polkit action | Privileged account/group mutation. | Remove `/usr/local/bin/modern-usersd` and the `.policy` file; nothing else depends on it. |
| Devuser creation (`install/system/create-devuser.sh`) | Creates a system account. | `sudo userdel -r devuser` if you want to remove it entirely. Autologin is unchanged. |
| Backup: snapper configs, the ESP-copy pacman hook | Touches `/etc/snapper`, `/etc/pacman.d/hooks`. | Delete the config/hook files; existing snapshots are untouched. |

**None of the files above are referenced by `install.sh`'s default run.**
`install.sh` only ever touches packages and the target user's stowed
dotfiles. A second, explicitly named script or flag is required for
anything in the table — see each script's own `--help`.

## The one side effect that isn't gated: packages

Installing packages is inherently system-wide (pacman has no per-user
scope) and is additive, so it isn't gated. It won't remove or break
anything `bastianweigand` uses.

One live fact worth knowing: `/etc/pacman.d/hooks/package_list.hook` on
this machine runs `backup_lists.sh` as `bastianweigand` after every pacman
transaction, rewriting `~/dotfiles/install/pkglist_*.txt`. Installing
`quickshell`, `matugen`, etc. will therefore show up as uncommitted churn
in the *old* dotfiles repo. **Decision: leave that hook alone, ignore the
diff.** We do not disable it, modify it, or commit to `~/dotfiles`. It's
hardcoded to `bastianweigand` and never fires for `devuser`.

The new system ships **no pacman hook** — package manifests under
`install/manifests/` are hand-curated files, not auto-generated. Run
`scripts/snapshot-packages.sh` manually whenever you want to audit drift
between the machine and the manifests.

## Verification

Run before every commit and before/after any install step, **from
`bastianweigand`**:

```bash
scripts/check-isolation.sh
```

It asserts:

1. `/etc/pacman.d/hooks/package_list.hook` is byte-identical to the
   snapshot taken at first run (`--init`).
2. No symlink inside `/home/bastianweigand/.config` points into this repo
   or into `/home/devuser`.
3. Gated files are absent (`greetd` enabled, `modern-usersd`,
   `tmpfiles.d/modern-session.conf`, `sysctl.d/99-modern-gaming.conf`,
   `esp-backup.hook`), unless `--allow-gated` is passed. Creating
   `devuser` is **not** a failure. Pre-existing Plymouth in mkinitcpio is
   not treated as a leak from this repo.
4. Home mtime under `bastianweigand` is **advisory** (WARN): a live
   account keeps writing caches. Real isolation is checks 1–3.

The script exits non-zero and prints exactly what changed if any check
fails, rather than a generic warning.

First-time baseline (once): `scripts/check-isolation.sh --init`.
