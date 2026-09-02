## Summary

<!-- What changed and why. One or two sentences. -->

## Test plan

- [ ] `scripts/lint-layers.sh` (if QML / i18n / layers changed)
- [ ] `scripts/test-settings-catalog.sh` (if Settings catalog changed)
- [ ] `scripts/test-desktop-sync.sh` (if update/sync changed)
- [ ] `./install/install.sh --dry-run --profile m0 --target /tmp/modern-install-dryrun` (if installer/stow changed)

Target branch is **`dev`**. Maintainers merge `dev` → `main` for a release.
