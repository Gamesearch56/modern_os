# Contributing

For developers who want to send changes to ModernOS: the branch
workflow, local checks to run, and the layer rules a pull request must
follow.

Work happens on `dev`. Open pull requests **into `dev`**. A release is a
PR **`dev` → `main`**. Do not open `feature/*` or `fix/*` branches.
Details: [`docs/GIT.md`](docs/GIT.md).

## Setup

1. Fork and clone, or clone this repo if you have push access.
2. `git checkout -b` is not the workflow here — check out `dev` and
   commit there, or branch from `dev` for a fork PR.
3. Arch Linux is the only supported host for a live install. CI runs
   layer lint, shellcheck, catalog/sync tests, and
   `install.sh --dry-run`.

```bash
scripts/ci-check.sh           # deps, layer lint, shellcheck, unit tests
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
- Keep the change one concern. Title says why.
- Fill in the PR template. Wait for CI (`checks` + `install-dry`).

## License

By contributing, you agree your work is licensed under
GPL-3.0-or-later with the additional terms in [`NOTICE`](NOTICE), the
same as the rest of ModernOS (see [`LICENSE`](LICENSE)). You keep the
copyright to your contribution. Every pull request is reviewed and
approved by the maintainer before it is merged
([`.github/CODEOWNERS`](.github/CODEOWNERS)).
