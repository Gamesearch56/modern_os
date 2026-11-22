<!--
Title: Release vX.Y.Z
Base: main, compare: dev. Merge with a merge commit, not squash.
Generate the body instead of filling this in by hand:
  scripts/release-notes.sh --pr vX.Y.Z
See docs/GIT.md, "Release".
-->

## What is in vX.Y.Z

<!-- Paste the sections printed by scripts/release-notes.sh --pr vX.Y.Z:
Breaking changes, Added, Changed, Deprecated, Removed, Fixed, Security,
Documentation, Maintenance. -->

## Release checklist

- [ ] `scripts/ci-check.sh` passes on `dev`
- [ ] The Calamares installer and the boot are tested from a local image
- [ ] Breaking changes, if any, explain what users have to do
- [ ] Highlights for the tag message are written
