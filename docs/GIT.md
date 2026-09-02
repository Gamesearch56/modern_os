# Git workflow

Friends install a **version** (`v1.2.3`), not every commit. Daily work
is on `dev`. A PR into `main` plus a tag is what they get.

Do **not** test a release on the machine you live on. Build the ISO and
try Calamares on a spare box, QEMU, or CI. Isolation: `docs/ISOLATION.md`.

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
`dev` **except the documented flip-day rewrite below**. GitHub branch
protection on `main` requires the CI checks below.

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

Forks also open PRs into `dev`. Maintainers commit on `dev` and PR
`dev` → `main`. See `CONTRIBUTING.md`.

## What “CI green” means

GitHub Actions on every PR to `main` or `dev`, on pushes to `dev` /
`main`, and on tags `v*`:

- `scripts/lint-layers.sh`
- `shellcheck` on `install/` and `scripts/`
- `scripts/test-settings-catalog.sh`
- `scripts/test-desktop-sync.sh` (local fake remote, no GitHub)
- `scripts/test-nautilus-prefs.sh`
- `scripts/test-iso-package-list.sh`
- `scripts/test-iso-live-kiosk.sh`
- `scripts/test-release-notes.sh`
- `./install/install.sh --dry-run --profile m0 --target $RUNNER_TEMP/…`

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
tag, publishes the GitHub Release, then dispatches the `ISO` workflow
to attach the image (`GITHUB_TOKEN` does not chain `release: published`).
Local test images: `sudo ./scripts/iso-build.sh --mkarchiso` then
`./scripts/iso-qemu.sh`. Never run `provision-iso.sh` or Calamares on
the session you live in.

That tag is what Settings → Update and the ISO pin look at. Friends
download the image from the Release page.

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
- `git push --force` to `main` or `dev` except flip day (below).
- Point a friend’s PC at `dev` (`git pull` / Settings against `dev`).
- Run `desktop-sync.sh apply` on a development clone while `HEAD` is
  dirty or not `dev`.
- Run Calamares or `provision-iso.sh` on a machine you live on.
  `iso-build.sh --mkarchiso` is allowed; it writes `iso/out/` only.

## Flip day (history rewrite, then public)

The repo can stay **private** indefinitely. When you choose to make it
public, history still contains names and older README copy until this
rewrite. Do this **once**, then change visibility.

1. Secret scan: [TruffleHog](https://github.com/trufflesecurity/trufflehog)
   plus a path scan for `secrets.json`, `.env`, and API-shaped strings.
2. Orphan-squash `main` and `dev` onto a new root (one commit each, or
   `dev` replayed on the squashed `main`). This is the only allowed
   force-push to those branches.
3. Delete leftover `feature/*` / `fix/*` remotes.
4. Tag **`v0.2.0`** on the new `main` (history break). Settings Update
   follows tags; friends on `v0.1.x` will see this as the next update.
5. GitHub → Settings → Danger Zone → Change visibility → Public.
6. Optional: topics, Issues, Discussions.

Until then, do not force-push and do not change visibility.

## GitHub settings (branch + Actions)

The repo stays **private**. Do not use Settings → Change visibility
until flip day.

**Already applied (works on a private user repo):**

- Actions → Workflow permissions: **Read** repository contents
  (`default_workflow_permissions=read`). `GITHUB_TOKEN` cannot approve
  PRs.
- Fork pull-request workflows in this private repo are **off** (no write
  tokens, no secrets). First-time-contributor approval is a GitHub
  setting that only exists once the repo is public.
- No `pull_request_target` workflows.

**Branch protection / rulesets:** GitHub returns 403 on this private
user-owned repo (`Upgrade to GitHub Pro or make this repository public`).
Apply the following **on flip day after the repo is public** (public
repos get branch protection on the free plan), or sooner if the account
has Pro.

`main` — require a PR, require status checks `checks` and `install-dry`,
no force-push, include administrators:

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

`dev` — do **not** require a PR; block force-push; include administrators:

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

After the repo is public, also set fork PRs to require approval for
first-time contributors:

```bash
gh api --method PUT repos/Gamesearch56/modern_dotfile/actions/permissions/fork-pr-contributor-approval \
  -f approval_policy=first_time_contributors_new_to_github
```

User-owned repos cannot restrict “who can push” via the `restrictions`
object (organization-only). Collaborators are still granted in Settings
→ Collaborators.
