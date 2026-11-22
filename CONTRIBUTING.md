# Contributing

For developers who want to send changes to ModernOS: the branch
workflow, local checks to run, and the layer rules a pull request must
follow.

Work happens on short-lived branches cut from `dev`, one issue per
branch, merged back into `dev` by pull request. A release is a PR
`dev` → `main`. Details: [`docs/GIT.md`](docs/GIT.md).

## Setup

1. Fork and clone, or clone this repo if you have push access.
2. Install the git hooks: `cp .githooks/* .git/hooks/`.
3. Arch Linux is the only supported host for a live install.

## Working on an issue

```bash
git fetch origin
git switch -c fix/57-bar-disappears-after-resume origin/dev
# with push access and gh: scripts/issue-branch.sh 57
```

Name the branch `fix/`, `feat/`, `docs/` or `chore/`, then the issue
number and a few words. Keep it to that one issue; rebase on
`origin/dev` if it falls behind.

Before you push:

```bash
scripts/ci-check.sh           # layer lint, shellcheck, unit tests
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
```

`iso-build.sh --mkarchiso` may write `iso/out/` on your machine. Do not run
`provision-iso.sh`, Calamares, or a live `install.sh` on a machine you
live on. Isolation: [`docs/ISOLATION.md`](docs/ISOLATION.md).

## Layer rules

See [`AGENTS.md`](AGENTS.md) and [`.cursorrules`](.cursorrules). Short version:

- `Commons` → nothing. `Services` → `Commons` only. `Widgets` are
  stateless. `Modules` compose widgets and read services.
- No hardcoded colors, durations, fonts, monitor names, or usernames.
- Every user-visible string goes through `I18n.t()`; add keys to both
  `translations/en.json` and `de.json`.
- New `Commons`/`Services`/`Widgets` files must be listed in that
  directory's `qmldir`.

## Pull requests

- Target **`dev`**, not `main`.
- Title: a Conventional Commit, for example
  `fix(audio): keep the headset profile after resume`. It becomes the
  release-notes line, so write it for users. Types and examples:
  [`docs/GIT.md`](docs/GIT.md#pr-title-and-description).
- Fill in the template: summary with `Fixes #N`, type of change,
  extra changelog lines, breaking changes, screenshots, how to test.
- No personal data in code, screenshots or pasted logs.
- CI must pass (**CI passed** and **Conventional PR title**).

## License

By contributing, you agree your work is licensed under
GPL-3.0-or-later with the additional terms in [`NOTICE`](NOTICE), the
same as the rest of ModernOS (see [`LICENSE`](LICENSE)). You keep the
copyright to your contribution. Every pull request is reviewed and
approved by the maintainer before it is merged
([`.github/CODEOWNERS`](.github/CODEOWNERS)).
