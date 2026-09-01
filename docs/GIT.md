# Git workflow

Friends install a **version** (`v1.2.3`), not every commit. You work on
branches. GitHub checks the work. Then you publish a release.

Do **not** test a release on the machine you live on. Build the ISO and
try Calamares on a spare box, QEMU, or CI — never against
`/home/bastianweigand` or this PC’s disk. Isolation: `docs/ISOLATION.md`.

## What is a branch?

A branch is a named line of commits. Your laptop can have many. GitHub
keeps two long-lived ones. Everything else is short-lived and gets
deleted after the pull request (PR) merges.

```
feature or fix branch  --PR, CI green-->  dev  --release PR, CI green-->  main  -->  tag vX.Y.Z  -->  friends
```

## The two sacred branches

| Branch | Who lands here | What friends see |
|--------|----------------|------------------|
| `dev` | Daily PRs | Nothing until you release |
| `main` | Release PRs only | The commit you tag |

Never commit on `main` or `dev` directly. Never `git push --force` to
either. GitHub branch protection should require the CI checks below.

## Start a feature (or a fix)

```bash
git checkout dev
git pull
git checkout -b feature/short-name
# or: git checkout -b fix/short-name
```

Do the work. Commit on that branch. Push it. Open a PR **into `dev`**.

## Open a PR

Title says why. Description says how to try it. Wait until CI is green,
then squash-merge into `dev`.

## What “CI green” means

GitHub Actions on every PR to `dev` or `main`, and on tags `v*`:

- `scripts/lint-layers.sh`
- `shellcheck` on `install/` and `scripts/`
- `scripts/test-settings-catalog.sh`
- `scripts/test-desktop-sync.sh` (local fake remote, no GitHub)
- `./install/install.sh --dry-run --profile m0 --target $RUNNER_TEMP/…`

`scripts/check-isolation.sh` is **this PC only**. Do not add it to GitHub.

## How to cut a release

When `dev` is what friends should get:

1. Open a PR **`dev` → `main`**. Title: `Release vX.Y.Z`.
2. Merge when CI is green.
3. Create a GitHub Release / annotated tag `vX.Y.Z` on that `main` commit.
4. After this workflow is on `main`, the `ISO` Action builds the friend
   image and attaches `*.iso` to that Release. Never `iso-build.sh
   --mkarchiso` on this PC.

```bash
git checkout main
git pull
git tag -a v0.1.0 -m "ModernOS v0.1.0"
git push origin v0.1.0
```

That tag is what Settings → Update and the ISO pin look at. Friends
download the image from the Release page, not from this machine.

**Semver:** `MAJOR.MINOR.PATCH`. Breaking desktop/install behavior bumps
MAJOR; features MINOR; fixes PATCH. Start at `v0.1.0` until you want
`v1.0.0`.

**Hotfix:** branch from `main`, PR back to `main`, tag `vX.Y.Z+1`, then
merge `main` into `dev` so the fix is not lost.

No `release/*` branches unless tagging from `main` becomes painful.

## What friends install

The ISO clones `https://github.com/Gamesearch56/modern_dotfile.git` at
the baked-in tag. Settings → Update lists **ModernOS** first. It is
pending only when a **newer** `vX.Y.Z` exists on GitHub. It never tracks
`dev` or the tip of `main`.

## What not to do

- Commit on `main` or `dev`.
- `git push --force` to `main` or `dev`.
- Point a friend’s PC at `dev` (`git pull` / Settings against `dev`).
- Run `desktop-sync.sh apply` on this development clone while `HEAD` is
  dirty or a feature branch.
- Run Calamares, `provision-iso.sh`, or `iso-build.sh --mkarchiso` on
  this PC.
