# Git workflow

For contributors and maintainers: how issues become branches, how pull
requests are titled and described, where the automated tests run, and
how a release is tagged and published.

Installed systems follow **release tags** (`v1.2.3`), never a branch.
Work lands on `dev` through short-lived topic branches; a release is a
PR `dev` → `main` plus a tag. Urgent fixes for the current release go
through a `hotfix/` branch straight into `main`.

```
           fix/12-…  feat/15-…  docs/…           hotfix/30-…
              \         |        /                    |
  dev ─────────●────────●───────●───── Release PR ──┐ |
                                                     v v
  main ───────────────────────────────────────────── ● ●──> tags vX.Y.Z
                                                        └─> merged back into dev
```

Do **not** test a release on your everyday machine. Build the ISO
locally and try Calamares on a spare machine or in QEMU. Isolation:
`docs/ISOLATION.md`.

## Branches

| Branch | Cut from | Merged into | How | Lives |
|--------|----------|-------------|-----|-------|
| `main` | — | — | PRs only | Forever. Every commit on it is released or about to be tagged |
| `dev` | — | `main` (release PR) | Merge commit | Forever. The integration branch; always installable |
| `fix/<issue>-<slug>` | `origin/dev` | `dev` | Squash | Until the PR is merged |
| `feat/<issue>-<slug>` | `origin/dev` | `dev` | Squash | Until the PR is merged |
| `docs/<slug>`, `chore/<slug>` | `origin/dev` | `dev` | Squash | Until the PR is merged |
| `hotfix/<issue>-<slug>` | newest tag on `main` | `main` | Squash | Until the hotfix is tagged |

One issue, one branch, one PR. A branch that grows a second concern
becomes two branches. Delete the branch when its PR is merged (GitHub's
"Automatically delete head branches" does it for you).

Never commit on `main`. Never `git push --force` to `main` or `dev`.
Force-pushing your own topic branch after a rebase is fine.

## From a report to a branch

Bug reports arrive two ways:

1. **In-app reports** (Super+# or `modern report`, see
   `docs/BUGREPORT.md`) open a **private** issue in
   `Gamesearch56/modern-reports` (`bugReport.repo` in
   `config.default.json`) when that computer is signed in to GitHub.
   They carry redacted logs, screenshots, the environment and a device
   summary. They are not published on this repository. A computer that
   is not signed in, or whose login cannot see the private repository,
   saves the report to Downloads and does not send it.
2. **Issues** through the bug form in this repository
   (`.github/ISSUE_TEMPLATE/bug.yml`). It asks for the version, the
   install type and the output of `modern device` (machine model,
   firmware and boot mode, CPU, memory, GPUs with driver, displays,
   audio server; serial numbers removed).

Triage, once per new issue:

1. Read it and reproduce it if you can. It already carries `Work Required`
   and an `area:*` label. When the fix is done, remove `Work Required`.
2. When the tracked issue should omit logs and screenshots, print a
   shorter draft and file that:

   ```bash
   scripts/report-to-issue.sh 42            # print the shorter draft
   scripts/report-to-issue.sh 42 --create   # edit it, file it, link it
   ```

   Only the Steps, Environment and Device sections are copied. The
   draft opens in `$EDITOR` first: the steps are the reporter's own
   words, so remove anything personal (names, addresses, network names)
   before saving.
3. Start the branch from the issue number:

   ```bash
   scripts/issue-branch.sh 57              # fix/57-<slug> from origin/dev
   scripts/issue-branch.sh 61 --type feat  # feat/61-<slug>
   scripts/issue-branch.sh 63 --hotfix     # hotfix/63-<slug> from the newest tag
   ```

   The type follows the issue's labels (`bug` → `fix`, `enhancement` →
   `feat`, `documentation` → `docs`) unless `--type` says otherwise. The
   script refuses to run with uncommitted changes and fetches first, so
   the branch starts from the current `dev`.

## Several issues at once

Each issue has its own branch, so switching is `git switch fix/57-…`.
To keep two branches checked out side by side (one building while you
edit the other), use worktrees instead of stashing:

```bash
git worktree add ../modern-57 fix/57-bar-disappears-after-resume
git worktree remove ../modern-57      # when the PR is merged
```

Keep a long-running branch current by rebasing it on `dev`, not by
merging `dev` into it; the PR is squashed anyway:

```bash
git fetch origin
git rebase origin/dev
git push --force-with-lease
```

Open the PR early as a **draft** when you want CI to run on work in
progress; mark it ready when it is.

## Commit messages

Commits on a topic branch are yours: write what helps you. Only the
**PR title** has to follow the convention below, because squash merging
turns the PR into one commit on `dev` whose subject is the PR title.

Commits made directly on `dev` (maintainer only, see Rulesets) follow
the same convention as PR titles.

## PR title and description

### Title

The title is a [Conventional Commit](https://www.conventionalcommits.org/):

```
type(scope): what changes, in the imperative, lower case, no full stop
```

`scripts/check-pr-title.sh` enforces it in CI (job **Conventional PR
title**); run it locally with the title as its argument. At most 72
characters. The scope is optional, lower case, and names the area:
`audio`, `bar`, `launcher`, `settings`, `installer`, `iso`, `update`…

The type decides where the change appears in the release notes:

| Type | Use for | Release-notes section |
|------|---------|-----------------------|
| `feat` | A new feature or option | Added |
| `fix` | A bug fix | Fixed |
| `remove` | A removed feature, setting or package | Removed |
| `deprecate` | A feature that will be removed later | Deprecated |
| `security` | A security fix | Security |
| `perf` | Faster or lighter, same behaviour | Changed |
| `docs` | Documentation only | Documentation |
| `refactor`, `style` | Code changes users cannot see | Maintenance |
| `build`, `ci`, `test`, `chore` | Packaging, CI, tests, housekeeping | Maintenance |
| `revert` | Undoing an earlier change | Changed |

A **breaking change** (users or their `config.json` must do something)
adds `!` after the type or scope: `feat(config)!: settings live in
config.json only`. It is listed under **Breaking changes**, at the top
of the release notes, instead of its type's section.

Examples:

```
fix(audio): keep the headset profile after resume
feat(launcher): calculator provider
remove(bar): the legacy clock widget
deprecate(theme): the fixed-brand profile
security(update): verify the tag signature before applying
feat(config)!: move bar layout into bar.sections
docs: explain the release flow
```

Release PRs are titled `Release vX.Y.Z`. GitHub's own `Revert "…"`
titles pass unchanged.

### Description

`.github/pull_request_template.md` fills itself in when you open the
PR. Write it for someone who does not know the code:

1. **Summary**: what changes for the user and why, one or two
   sentences. Then `Fixes #57` (or `Refs #57` when it does not fully
   fix it). `main` is the default branch, so merging into `dev` does
   not close the issue yet: the squash commit carries `Fixes #57` in
   its body, and GitHub closes the issue when the release PR brings
   that commit into `main`. An issue stays open until its fix ships.
   A hotfix PR targets `main` and closes its issue on merge.
2. **Type of change**: tick one or more boxes.
3. **Changelog**: the title is the main release-notes line. If the PR
   has more user-visible changes, add one line per change, starting at
   the beginning of the line with the section name and a colon:

   ```
   Removed: the old calculator prefix
   Fixed: the launcher no longer loses focus on a second monitor
   ```

   Accepted names: `Breaking`, `Added`, `Changed`, `Deprecated`,
   `Removed`, `Fixed`, `Security`. `scripts/release-notes.sh` reads
   these lines from the squash commit's body.
4. **Breaking changes**: what users have to do, or "None".
5. **Screenshots** for visible UI changes, before and after. Crop out
   names, email addresses, hostnames, Wi-Fi networks and notifications.
6. **How to test**: steps a reviewer can follow on an install or a VM.
7. **Checklist**: base branch, `scripts/ci-check.sh`, both translation
   files, docs, and no personal data.

### Merging

Topic and hotfix PRs: **Squash and merge**. Keep the title as the
commit subject. In the commit body keep `Fixes #N` and the Changelog
lines; the rest of the template can be deleted in the merge dialog.
Release PRs (`dev` → `main`) and the merge back into `dev`: **Create a
merge commit**, so `main` and `dev` keep sharing history.

## Where the automated tests run

| When | Where | What runs | Blocks |
|------|-------|-----------|--------|
| `git commit` | `.githooks/pre-commit` | `ci-check.sh lint`: layer lint, translations, shellcheck | The commit |
| `git push` | `.githooks/pre-push` | `ci-check.sh`: lint, then every unit test | The push |
| PR opened, updated or retitled | GitHub Actions `PR title` | `check-pr-title.sh` | The merge |
| PR into `dev` or `main`, push to them | GitHub Actions `CI` | `lint` → `unit` and `install-dry` (below) → **CI passed** | The merge |
| Before the release PR is merged | Your machine | `iso-build.sh --mkarchiso`, install in QEMU (`scripts/iso-qemu.sh`) | The release |
| Tag `vX.Y.Z` pushed | GitHub Actions `Release` | Tag is on `main`, then release notes | The GitHub Release |
| Mondays, or by hand | GitHub Actions `Weekly` | `check-manifests.sh`: every manifest package still exists in the Arch repos and the AUR | Opens an issue |

Install the hooks once per clone: `cp .githooks/* .git/hooks/`.

The `CI` workflow, cheapest stage first, so a lint error never waits for
the Arch container:

1. **lint** (Ubuntu, pinned shellcheck): `scripts/ci-check.sh lint`,
   which runs `lint-layers.sh` (layer imports, hardcoded values,
   translation keys in both files, file length) and shellcheck on
   `install/`, `scripts/`, `tests/`, `iso/airootfs/`.
2. **unit** (after lint): `scripts/ci-check.sh test`, every `tests/test-*`
   script listed in `ci-check.sh`.
3. **install-dry** (after lint, in parallel with unit): `install.sh
   --dry-run` in an `archlinux:latest` container for m0/AMD, m0/Intel,
   gaming/NVIDIA and full/AMD. It catches manifest, profile and
   GPU-layer mistakes without installing anything.
4. **CI passed**: succeeds only when all of the above did. It is the one
   check the rulesets require, so adding a matrix entry never means
   editing the rulesets.

CI does **not** build the ISO: one image is past the free Actions
storage quota, and a QEMU install needs KVM. Both stay local, once per
release candidate. `scripts/check-isolation.sh` is local only as well.

A new test is a `tests/test-<name>.sh` (or `.py`) plus a line in
`scripts/ci-check.sh`; CI picks it up from there.

## Release

### 1. Pick the version

[Semver](https://semver.org/) `MAJOR.MINOR.PATCH`, from the types merged
since the last tag:

- any breaking change: MAJOR (while the version is `0.x`, MINOR)
- any `feat`: MINOR
- only fixes and maintenance: PATCH

### 2. Release candidate

On an up-to-date `dev`: `scripts/ci-check.sh`, build the ISO with
`sudo ./scripts/iso-build.sh --mkarchiso`, and install it in QEMU
(`scripts/iso-qemu.sh`). Fix what breaks through the usual topic
branches first.

### 3. Release PR

Generate the description, then open the PR `dev` → `main`:

```bash
git switch dev && git pull
scripts/release-notes.sh --pr v0.8.0 >/tmp/release-pr.md
gh pr create --base main --head dev --title "Release v0.8.0" --body-file /tmp/release-pr.md
```

`--pr` lists everything on `dev` since the newest tag in the release
sections (Breaking changes, Added, Changed, Deprecated, Removed, Fixed,
Security, Documentation, and Maintenance folded away) and appends the
release checklist. Read it as a user would: a vague title is easier to
fix now, by editing the PR text, than after the tag. The manual
alternative is `.github/PULL_REQUEST_TEMPLATE/release.md`
(`?template=release.md` on the compare page).

Merge with **Create a merge commit** when CI is green.

### 4. Tag

An annotated tag on the merge commit. The first line of its message is
the release title; everything after the first blank line becomes the
**Highlights** at the top of the release notes, two to five sentences on
what matters most to users:

```bash
git switch main && git pull
cat >/tmp/tag.txt <<'EOF'
ModernOS v0.8.0

Headsets switch between music and call profiles from the volume panel.
The launcher calculates as you type. The legacy clock widget is gone;
the clock in the bar replaces it.
EOF
git tag -a v0.8.0 -F /tmp/tag.txt
git push origin v0.8.0
```

### 5. GitHub Release

Title: `ModernOS vX.Y.Z`. Body: `scripts/release-notes.sh vX.Y.Z`,
which prints

```
## [0.8.0] - 2026-11-29
### Highlights          from the tag message
### Breaking changes    with what to do
### Added / Changed / Deprecated / Removed / Fixed / Security / Documentation
<details> Maintenance </details>
### Upgrading           Settings → Update (the ISO sentence is added with the image)
[Full changelog](…/compare/v0.7.7...v0.8.0)
```

The `Release` workflow publishes it on the tag push, after checking the
tag is on `main`. It only creates releases: one that already exists is
left alone. When Actions cannot run, publish it by hand:

```bash
scripts/release-notes.sh v0.8.0 >/tmp/notes.md
gh release create v0.8.0 --verify-tag --title "ModernOS v0.8.0" --notes-file /tmp/notes.md
```

Then attach the image (next section). That adds the Download section
and the line “New installations: download the ISO from this page.”
The line is not in the notes until the image is a release asset.

### 6. Merge back

`main` now has a merge commit `dev` does not. Bring it back, so the next
release PR starts from this tag:

```bash
git switch dev && git pull
git merge --ff-only origin/main || git merge --no-edit origin/main
git push origin dev
```

## Hotfix

For a bug in the current release that cannot wait for the next one:

1. `scripts/issue-branch.sh 63 --hotfix` cuts `hotfix/63-<slug>` from
   the newest tag on `main`.
2. Fix it, then open the PR **into `main`** with a normal title
   (`fix(lock): …`) and `Fixes #63`. Squash-merge when CI is green.
3. Tag the PATCH version on `main` exactly as in Release step 4
   (`v0.8.1`), push it, and attach the ISO if the bug affects
   installation.
4. Merge back into `dev` as in Release step 6. A conflict there means
   `dev` changed the same code; resolve it on `dev`.

## Release ISO

Once the GitHub Release exists, start the image build and leave it
running. It asks for sudo once, checks the upload itself, and does not
need anyone watching it:

```bash
git checkout vX.Y.Z
scripts/iso-release.sh vX.Y.Z    # sudo asks once; a window asks when there is no terminal
git checkout dev
```

It builds with `iso-build.sh --mkarchiso --public`, which leaves the
deploy key out. Then it lists the image's squashfs and stops if any
credential is in it: a deploy key, `secrets/`, `secrets.json`, SSH or
GnuPG private keys. It writes `SHA256SUMS` and signs it with the key in
`docs/release-key.asc`. It uploads `modernos-x86_64.iso`, `SHA256SUMS`
and `SHA256SUMS.asc`, compares GitHub's SHA-256 of the upload with the
local one, and puts a Download section after the full changelog.
Re-running is safe: a matching upload is not sent again, and the
Download section is replaced, not added twice.

The asset name has no version, so one link always serves the newest
image, for the website or anywhere else:

```
https://github.com/Gamesearch56/modern_os/releases/latest/download/modernos-x86_64.iso
```

A release does not pass `--with-deploy-key`. That flag builds without
`--public` and lets exactly `/usr/lib/modern/deploy_key` through the
check (and requires it). The image then carries a key. Do not publish
that image.

GitHub takes assets under 2 GiB; the script refuses a larger image
before uploading.

The command above stops after the GitHub upload. It does not copy the
image to Proton Drive.

**Archive copy (Proton Drive), only when asked.** With an rclone remote
configured (`rclone config`, type `protondrive`), pass
`--archive proton:ModernOS/releases`. Each release then lands in its
own `vX.Y.Z/` folder and is compared with `rclone check`. rclone keeps
its credentials in its own config, never in this repo. An exported
`MODERNOS_ISO_ARCHIVE` does not turn this on.

The image upload opens a progress window when a desktop session is
available. With `--archive` and two-factor login, the code is needed
once, not per release: the first successful login stores a session in
rclone's config, and later runs refresh it without a code. When Proton
asks again, the script opens a window for the code, the same way it
asks for the sudo password when there is no terminal. Proton
rate-limits repeated logins: wait a few minutes rather than retrying
in a loop.

**Signing key, once.** A key used only for ModernOS releases, not your
personal one. Its user ID is public, so give it a project address (or
none), never a private one:

```bash
gpg --quick-gen-key "ModernOS Releases <releases@example.org>" ed25519 sign 3y
gpg --armor --export "ModernOS Releases" >docs/release-key.asc
```

Commit `docs/release-key.asc`. Back up the secret key offline
(`gpg --export-secret-keys --armor`); a lost key means users see a new
fingerprint they cannot tell from an attacker's.

## What a release installs

The ISO clones `https://github.com/Gamesearch56/modern_os.git` at
the baked-in tag. Settings → Update lists **ModernOS** first. It is
pending only when a **newer** `vX.Y.Z` exists on GitHub. It never tracks
`dev` or the tip of `main`.

## Keeping personal data out

Everything in this repository, its issues, pull requests and releases
is public. Before you push or publish:

- No secrets: API keys and tokens live in the gitignored `secrets.json`,
  deploy keys in `secrets/`. `iso-release.sh` refuses an image that
  contains either.
- No personal addresses, real names of reporters, hostnames, usernames,
  home paths, Wi-Fi names or serial numbers in code, docs, examples, PR
  text or release notes. Use `example.org`, `user`, `/home/user`.
- Screenshots: crop notifications, account names and network lists.
- Logs pasted into an issue: the in-app reporter redacts them
  (`scripts/lib/report-redact.py`); anything pasted by hand is checked
  by you. `scripts/report-to-issue.sh` can open a shorter issue that
  leaves logs and screenshots out.

## What not to do

- Commit on `main`, or open a topic PR into `main` (only release and
  hotfix PRs go there).
- Mix two issues in one branch.
- Squash a release PR, or the merge back into `dev`.
- `git push --force` to `main` or `dev`.
- Point an installed machine at `dev` (`git pull` / Settings against
  `dev`).
- Run `desktop-sync.sh apply` on a development clone while `HEAD` is
  dirty or not `dev`.
- Run Calamares or `provision-iso.sh` on your everyday machine.
  `iso-build.sh --mkarchiso` is allowed; it writes `iso/out/` only.

## ISO size

`iso-build.sh` copies stock archiso **releng** for bootloaders and
airootfs layout, then **replaces** `packages.x86_64` with
`iso/releng/packages.x86_64` (the full live+Calamares set). Keep
`rsync` and `python` — Calamares `unpackfs` is a Python module that
copies `airootfs.sfs` with `rsync`, and the AUR package declares
neither. Exit 127 is a missing binary. Rescue tools (Clonezilla, TestDisk,
`archinstall`, extra filesystems) stay off the squashfs. Stock `linux`
stays off so the image fits GitHub's 2 GiB release-asset cap; live boot
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

## Repository settings (you apply)

**Pull requests** (Settings → General):

- Allow **squash merging**, default message **Pull request title and
  description** (so `Fixes #N` and the Changelog lines reach the
  commit); allow **merge commits**; turn **rebase merging** off.
- **Automatically delete head branches**: on.
- Default branch: `main`. It is what visitors see and what releases
  are cut from. GitHub preselects it as the base of a new PR, so switch
  the base to `dev` for topic branches; the template's checklist asks.

**Labels**, once:

```bash
for l in "Work Required" confirmed breaking area:display area:hyprland \
         area:quickshell area:audio area:bluetooth area:network area:games \
         area:updates area:session area:applications area:system-apps \
         area:filesystem area:peripherals area:power area:design area:other; do
  gh label create "$l" --force
done
```

`bug`, `enhancement` and `documentation` exist by default. The `area:*`
names match what the in-app reporter sets.

### Rulesets

Use **Settings → Rules → Rulesets** (preferred) or classic
**Settings → Branches**.

**`main`**

- Block force pushes, restrict deletions
- Require a pull request, **0** approving reviews (a required review
  would block your own PRs unless you add a bypass)
- Required status checks: **CI passed** and **Conventional PR title**
- Require branches to be up to date
- Bypass list: empty

**`dev`**

- Block force pushes, restrict deletions
- Require a pull request, **0** approving reviews
- Required status checks: **CI passed** and **Conventional PR title**
- Bypass list: your account, and only for merging `main` back after a
  release. Everyday fixes and features do not use it.

**Repository / Actions**

- **Collaborators:** leave empty (solo). User-owned repos cannot use
  the org-only `restrictions` “who can push” object.
- **Actions → General:** workflow permissions **Read** repository
  contents. `release.yml` and `weekly.yml` ask for the extra
  `contents: write` / `issues: write` they need themselves.
- **Actions → Fork pull request workflows:** require approval for all
  outside collaborators (`all_external_contributors`). Your own pull
  requests still run.
- **Code security:** enable secret scanning and push protection. Keep
  private vulnerability reporting (`SECURITY.md`).
- **Dependabot:** keep `.github/dependabot.yml`; its PRs target `dev`.
- Optional: turn off Wiki / Projects if unused; leave Issues on for
  public bug reports.

Do **not** add `pull_request_target` workflows.

Classic API calls, if you prefer them over the Rulesets UI:

```bash
gh api --method PUT repos/Gamesearch56/modern_os/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      {"context": "CI passed"},
      {"context": "Conventional PR title"}
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
gh api --method PUT repos/Gamesearch56/modern_os/branches/dev/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      {"context": "CI passed"},
      {"context": "Conventional PR title"}
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
gh api --method PUT repos/Gamesearch56/modern_os/actions/permissions/fork-pr-contributor-approval \
  -f approval_policy=all_external_contributors
```
