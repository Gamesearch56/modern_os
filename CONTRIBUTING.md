# Contributing

Work happens on `dev`. Friends and forks open pull requests **into `dev`**.
Maintainers commit on `dev` and open a PR **`dev` → `main`** when a
release (or hotfix) should ship. Do not open `feature/*` or `fix/*`
branches. Details: [`docs/GIT.md`](docs/GIT.md).

## Setup

1. Fork and clone, or clone this repo if you have push access.
2. `git checkout -b` is not the workflow here — check out `dev` and
   commit there (maintainers) or branch from `dev` for a fork PR.
3. Arch Linux is the only supported host for a live install. CI runs
   layer lint, shellcheck, catalog/sync tests, and
   `install.sh --dry-run`.

```bash
scripts/lint-layers.sh
scripts/test-settings-catalog.sh
scripts/test-desktop-sync.sh
./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun
```

Do not run `iso-build.sh --mkarchiso`, `provision-iso.sh`, or a live
`install.sh` on a machine you live on. Isolation: [`docs/ISOLATION.md`](docs/ISOLATION.md).

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
- Keep the change one concern. Title says why.
- Fill in the PR template. Wait for CI (`checks` + `install-dry`).

## License

By contributing, you agree your work is licensed under Apache-2.0
(see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE)).
