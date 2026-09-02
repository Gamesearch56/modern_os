# Git workflow

Friends install a **version** (`v1.2.3`), not every commit. Daily work
is on `dev`. A PR into `main` plus a tag is what they get.

Do **not** test a release on the machine you live on. Build the ISO and
try Calamares on a spare box, QEMU, or CI — never against
`/home/bastianweigand` or this PC’s disk. Isolation: `docs/ISOLATION.md`.

```
dev  --PR, CI green-->  main  -->  tag vX.Y.Z  -->  friends
```

## The two branches

| Branch | Who lands here | What friends see |
|--------|----------------|------------------|
| `dev` | Direct commits | Nothing until you release |
| `main` | PRs from `dev` only | The commit you tag |

Do **not** create `feature/*` or `fix/*` branches. Commit on `dev` and
push it. Never commit on `main`. Never `git push --force` to `main` or
`dev`. GitHub branch protection on `main` should require the CI checks
below.

## Daily work

```bash
git checkout dev
git pull
# edit, commit, push
git push origin dev
```

## Open a PR

When `dev` should become a release (or a hotfix friends need now), open
a PR **`dev` → `main`**. Title says why. Description says how to try it.
Wait until CI is green, then merge.

## What “CI green” means

GitHub Actions on every PR to `main`, on pushes to `dev` / `main`, and
on tags `v*`:

- `scripts/lint-layers.sh`
- `shellcheck` on `install/` and `scripts/`
- `scripts/test-settings-catalog.sh`
- `scripts/test-desktop-sync.sh` (local fake remote, no GitHub)
- `./install/install.sh --dry-run --profile m0 --target $RUNNER_TEMP/…`

`scripts/check-isolation.sh` is **this PC only**. Do not add it to GitHub.

## How to cut a release

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

**Hotfix:** same path — commit on `dev`, PR into `main`, tag `vX.Y.Z+1`.
After a release, `git checkout dev && git merge main` so `dev` is not
behind.

No `release/*` branches unless tagging from `main` becomes painful.

## What friends install

The ISO clones `https://github.com/Gamesearch56/modern_dotfile.git` at
the baked-in tag. Settings → Update lists **ModernOS** first. It is
pending only when a **newer** `vX.Y.Z` exists on GitHub. It never tracks
`dev` or the tip of `main`.

## What not to do

- Commit on `main`.
- Open PRs from `feature/*` / `fix/*` branches.
- `git push --force` to `main` or `dev`.
- Point a friend’s PC at `dev` (`git pull` / Settings against `dev`).
- Run `desktop-sync.sh apply` on this development clone while `HEAD` is
  dirty or not `dev`.
- Run Calamares, `provision-iso.sh`, or `iso-build.sh --mkarchiso` on
  this PC.
