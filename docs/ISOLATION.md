# Isolation: keeping the current user safe

`modern_dotfile` is built and iterated on while `bastianweigand` remains the
daily-driver account on this machine. Nothing here may break that account
until you explicitly decide the new system is ready and run the gated
system-wide phase yourself.

## Safe by construction

- All development lives in this repo, at
  `/home/bastianweigand/CursorProjects/modern_dotfile`. Nothing is ever
  written to `~/.config/`, `~/.local/`, `~/dotfiles/` or `~/.bashrc` for the
  `bastianweigand` account.
- `stow` is never invoked against `bastianweigand`'s home. It only ever
  targets `/home/devuser` (or `--target` explicitly passed by whoever runs
  `install.sh`).
- All runtime state this project creates lives under `devuser`'s home or
  the new `/var/lib/modern/` path — nothing pre-existing reads either.
- `~/dotfiles` (the old repo) is read-only reference material. It is never
  committed to, never modified, from this repo or its scripts.

## Gated: system-wide changes

These affect the whole machine, not one account, so they are **staged as
files under `install/system/` and never applied automatically**. Applying
them is a separate, explicit, human-invoked step — see each file's header
comment for the exact command.

| Change | Why it's gated | Rollback |
|---|---|---|
| `greetd` enablement | Replaces autologin machine-wide. A broken greeter locks out *both* users graphically. | `sudo systemctl disable greetd`, re-enable the previous getty autologin unit, reboot. Documented in the file header of `install/system/greetd/config.toml`. |
| Plymouth theme + `mkinitcpio` hooks | Rewrites the initramfs. A bad rebuild can leave the machine unable to boot. | `sudo mkinitcpio -P` after reverting `/etc/mkinitcpio.conf`; the previous initramfs stays as a fallback boot entry — never delete it. |
| `sysctl.d`, `polkit` actions, `tmpfiles.d`, udev rules, gaming perf sysctls | System-wide kernel/session policy. | Remove the dropped-in file under `/etc/{sysctl.d,polkit-1,tmpfiles.d,udev/rules.d}/modern-*` and reload (`sysctl --system`, `systemctl restart polkit`, `systemd-tmpfiles --create`). |
| `modern-usersd` + its polkit action | Privileged account/group mutation. | Remove `/usr/local/bin/modern-usersd` and the `.policy` file; nothing else depends on it. |
| Devuser creation (`install/system/create-devuser.sh`) | Creates a system account. | `sudo userdel -r devuser` if you want to remove it entirely. |
| Backup: snapper configs, the ESP-copy pacman hook | Touches `/etc/snapper`, `/etc/pacman.d/hooks`. | Delete the config/hook files; existing snapshots are untouched. |

**None of the files above are referenced by `install.sh`'s default run.**
`install.sh` only ever touches packages and `devuser`'s stowed dotfiles. A
second, explicitly named script or flag is required for anything in the
table — see each script's own `--help`.

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

Run before every commit and before/after any install step:

```bash
scripts/check-isolation.sh
```

It asserts:

1. No file under `/home/bastianweigand/` outside this repo has a newer
   mtime than the isolation baseline recorded at first run.
2. No symlink inside `/home/bastianweigand/.config` points into this repo
   or into `/home/devuser`.
3. `greetd.service`, `plymouth`-related mkinitcpio hooks, and any
   `modern-*` systemd/polkit/tmpfiles/sysctl file are absent or in their
   pre-existing state, unless `--allow-gated` is passed (meaning you've
   deliberately opened the gate).
4. `/etc/pacman.d/hooks/package_list.hook` is byte-identical to the
   snapshot taken at first run.

The script exits non-zero and prints exactly what changed if any check
fails, rather than a generic warning.
