# Git workflow

For contributors and maintainers: how branches, pull requests, release
tags and GitHub settings work for ModernOS, and how installed systems
pick up a release.

Installers use a **version** (`v1.2.3`), not every commit. Daily work
is on `dev`. A PR into `main` plus a tag is what they get.

Do **not** test a release on your everyday machine. Build the ISO
locally and try Calamares on a spare machine or in QEMU. Isolation:
`docs/ISOLATION.md`.

```
dev  --PR, CI green-->  main  -->  tag vX.Y.Z  -->  Releases
```

## The two branches

| Branch | Who lands here | What a release tag sees |
|--------|----------------|-------------------------|
| `dev` | Direct commits | Nothing until you release |
| `main` | PRs from `dev` only | The commit you tag |

Do **not** create `feature/*` or `fix/*` branches. Commit on `dev` and
push it. Never commit on `main`. Never `git push --force` to `main` or
`dev` **except the optional flip-day rewrite below**.

## Daily work

```bash
git checkout dev
git pull
# edit, commit, push
git push origin dev
```

## Open a PR

When `dev` should become a release (or a hotfix), open a PR
**`dev` → `main`**. Title says why. Description says how to try it.
Wait until CI is green, then merge.

Forks open their PRs into `dev` as well. Only the maintainer opens
`dev` → `main`. See `CONTRIBUTING.md`.

## What “CI green” means

GitHub Actions on every PR to `main` or `dev`, on pushes to `dev` /
`main`, and on tags `v*`:

- `scripts/ci-check.sh` (jq / python3 / git / shellcheck, then
  `lint-layers.sh`, `shellcheck` on `install/` `scripts/` `iso/airootfs/`,
  and the catalog / sync / nautilus / ISO kiosk / Calamares late / Calamares
  patch / release-notes tests)
- `./install/install.sh --dry-run --profile m0 --target $RUNNER_TEMP/…`

CI does **not** build the ISO: one 1.8 GB image is past the free
Actions storage quota. Build it locally with
`sudo ./scripts/iso-build.sh --mkarchiso` (output in `iso/out/`), and
for an unattended install test run `tests/test-iso-qemu-install.sh`.

`scripts/check-isolation.sh` is **local only**. Do not add it to GitHub.

## How to cut a release

1. Open a PR **`dev` → `main`**. Title: `Release vX.Y.Z`.
2. Merge when CI is green.
3. Annotated tag on that `main` commit, then push the tag. Do **not**
   write the GitHub Release by hand.

```bash
git checkout main
git pull
git tag -a v0.1.0 -m "ModernOS v0.1.0"
git push origin v0.1.0
```

The `Release` Action writes [Keep a Changelog](https://keepachangelog.com/)
notes (Added / Changed / Fixed / …) from commits since the previous
tag and publishes the GitHub Release. It does not build or attach an
ISO. Build the image locally with `sudo ./scripts/iso-build.sh
--mkarchiso`, test it with `./scripts/iso-qemu.sh`, and upload it to the
Release by hand (`gh release upload vX.Y.Z iso/out/*.iso`) if you want it
there. Never run `provision-iso.sh` or Calamares on
the session you live in.

That tag is what Settings → Update and the ISO pin look at.

**Semver:** `MAJOR.MINOR.PATCH`. Breaking desktop/install behavior bumps
MAJOR; features MINOR; fixes PATCH. Start at `v0.1.0` until you want
`v1.0.0`.

**Hotfix:** same path — commit on `dev`, PR into `main`, tag `vX.Y.Z+1`.
After a release, `git checkout dev && git merge main` so `dev` is not
behind.

No `release/*` branches unless tagging from `main` becomes painful.

## What a release installs

The ISO clones `https://github.com/Gamesearch56/modern_dotfile.git` at
the baked-in tag. Settings → Update lists **ModernOS** first. It is
pending only when a **newer** `vX.Y.Z` exists on GitHub. It never tracks
`dev` or the tip of `main`.

## Private repo, while you are still testing

Maintainer notes for a fork or mirror that is still private. A public
repository needs none of this. A read-only **deploy key** lets an installed laptop fetch those tags
without the repository being public. It is not your account SSH key.
GitHub attaches it to this one repo, and it cannot push.

```bash
scripts/deploy-key-init.sh
```

That writes `secrets/github-deploy-key` (gitignored, mode 600) and prints
the public half. Add the public half under GitHub → this repo →
Settings → Deploy keys, and leave **Allow write access** off.

`iso-build.sh` copies the private half into the image only when that
file exists, root-owned and mode 600. Calamares then moves it to
`~/.config/modern/deploy_key` for the new user and deletes the system
copy. Settings → Update uses it for
`git@github.com:Gamesearch56/modern_dotfile.git` only: no other SSH key,
no `~/.ssh/config`, and GitHub's host key checked against
`scripts/lib/github-known-hosts`. With no key file, updates stay on
HTTPS.

The private half is inside the ISO. Anyone with that file can read this
repo. They still cannot push. If an image gets passed around, delete the
key on GitHub and run `deploy-key-init.sh` again (it will not overwrite;
move the old file aside first).

When you make the repo public, revoke the deploy key and delete
`secrets/github-deploy-key` before the next ISO build. Updates then use
HTTPS and nothing else changes.

## What not to do

- Commit on `main`.
- Open PRs from `feature/*` / `fix/*` branches.
- `git push --force` to `main` or `dev` except the optional flip-day
  rewrite (below).
- Point an installed machine at `dev` (`git pull` / Settings against
  `dev`).
- Run `desktop-sync.sh apply` on a development clone while `HEAD` is
  dirty or not `dev`.
- Run Calamares or `provision-iso.sh` on your everyday machine.
  `iso-build.sh --mkarchiso` is allowed; it writes `iso/out/` only.

## Flip day (you change visibility)

Maintainer checklist for turning a private repository public. You flip
GitHub visibility. This tree does not. Optional history squash
is also yours, and it must happen **before** branch protection —
force-push is blocked after that.

1. Secret scan on **history**: run
   [TruffleHog](https://github.com/trufflesecurity/trufflehog) (or
   equivalent) against the full git history. The working tree can be
   clean and history still not. Also path-scan for `secrets.json`,
   `secrets/github-deploy-key`, `.env`, and API-shaped strings.
2. Optional: orphan-squash `main` and `dev` onto a new root (one commit
   each, or `dev` replayed on the squashed `main`). This is the only
   allowed force-push to those branches.
3. Delete leftover `feature/*` / `fix/*` remotes if any remain.
4. Revoke the read-only deploy key (Settings → Deploy keys) and delete
   `secrets/github-deploy-key` so later ISOs do not embed it.
5. GitHub → Settings → Danger Zone → Change visibility → Public.
6. Then apply the rulesets below. **Do not enable “block force-push”
   until the optional squash is done.**
7. After the repo is public: enable secret scanning and push protection
   (free on public repos). Keep private vulnerability reporting
   (`SECURITY.md`).

Until you are ready, do not force-push and do not change visibility.

Residual risk if you skip the history squash: past commits stay
cloneable. That choice stays yours.

### ISO size

`iso-build.sh` copies stock archiso **releng** for bootloaders and
airootfs layout, then **replaces** `packages.x86_64` with
`iso/releng/packages.x86_64` (the full live+Calamares set). Keep
`rsync` and `python` — Calamares `unpackfs` is a Python module that
copies `airootfs.sfs` with `rsync`, and the AUR package declares
neither. Exit 127 is a missing binary. Rescue tools (Clonezilla, TestDisk,
`archinstall`, extra filesystems) stay off the squashfs. Stock `linux`
stays off so the image fits GitHub's 2 GiB release-asset cap; live boot
is `linux-zen` (`iso-build.sh` rewrites releng `vmlinuz-linux` paths).
`linux-zen-headers` stay off the ISO; `install.sh` /
`00-base.txt` still have them for DKMS. Firefox stays (live kiosk). AUR
builds use `MAKEFLAGS=-j$(nproc)` and cache `.pkg.tar.*` beside
`iso/out/` (gitignored). The AUR list ships `yay-bin`.

Do not switch squashfs to zstd — it is usually bigger.

Do **not** take Hyprland, Quickshell, PipeWire, `yay-bin`,
`matugen-bin`, or `bibata-cursor-theme-bin` off the squashfs. That is
the copy-the-live-root installer. Do not drop `linux-firmware` if
real-hardware Wi-Fi still matters. Build and try the image in QEMU,
never with `provision-iso.sh` / Calamares on your everyday machine.

## After the repo is public (you apply)

Use **Settings → Rules → Rulesets** (preferred) or classic
**Settings → Branches**. Do this **after** any history rewrite, and
**after** the repo is public. Private user repos on the free plan
cannot use branch protection.

**`main` (release branch)**

- Target: branch named `main`
- Block force pushes (only after the optional squash)
- Restrict deletions
- Require a pull request before merging, **0** approving reviews (a
  required review of 1 would block your own `dev` → `main` PRs unless
  you add a bypass)
- Require status checks to pass: `checks` and `install-dry` (job names
  in `.github/workflows/ci.yml`)
- Optionally “Require branches to be up to date”
- Bypass list: **empty** if even your account should go through a PR;
  or add yourself only if you still want a `main` hotfix hatch (that
  fights “never commit on `main`”)

**`dev` (daily push branch)**

- Target: branch named `dev`
- Block force pushes (only after the optional squash)
- Restrict deletions
- **Do not** require a pull request (you push `dev` directly)
- Do not require status checks on push (CI still runs after push;
  requiring checks would block `git push origin dev` until Actions
  finishes)

**Repository / Actions**

- **Collaborators:** leave empty (solo). User-owned repos cannot use
  the org-only `restrictions` “who can push” object.
- **Actions → General:** workflow permissions **Read** repository
  contents (already the intent in `ci.yml`). Do not grant GITHUB_TOKEN
  write/approve.
- **Actions → Fork pull request workflows:** require approval for
  first-time contributors (`first_time_contributors_new_to_github`).
- **Code security:** enable secret scanning and push protection. Keep
  private vulnerability reporting (`SECURITY.md`).
- **Dependabot:** keep `.github/dependabot.yml`; its PRs should target
  `dev`.
- Optional: turn off Wiki / Projects if unused; leave Issues on for
  public bug reports.

Do **not** add `pull_request_target` workflows.

Classic API calls, if you prefer them over the Rulesets UI. Run these
yourself after the repo is public — not before the optional squash
enables force-push block:

```bash
gh api --method PUT repos/Gamesearch56/modern_dotfile/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      {"context": "checks"},
      {"context": "install-dry"}
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
gh api --method PUT repos/Gamesearch56/modern_dotfile/branches/dev/protection \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
gh api --method PUT repos/Gamesearch56/modern_dotfile/actions/permissions/fork-pr-contributor-approval \
  -f approval_policy=first_time_contributors_new_to_github
```
