<!--
Title: a Conventional Commit, it becomes the squash commit and the
release-notes line. Examples:
  fix(audio): keep the headset profile after resume
  feat(launcher): calculator provider
  remove(bar): the legacy clock widget
See docs/GIT.md, "PR title and description".
Release PRs (dev -> main): use ?template=release.md or
scripts/release-notes.sh --pr vX.Y.Z instead of this template.
-->

## Summary

<!-- What changes for the user and why, in one or two sentences. -->

Fixes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Change to existing behaviour
- [ ] Removed or deprecated feature
- [ ] Security fix
- [ ] Documentation
- [ ] Build, CI, tests or refactor (no user-visible change)

## Changelog

<!--
The PR title is the main release-notes entry. If this PR has more
user-visible changes, add one line each that starts with a section
name and a colon: Added, Changed, Deprecated, Removed, Fixed, Security
or Breaking. For example:
    Removed: the old calculator prefix
Leave this section empty when the title says it all.
-->

## Breaking changes

<!-- What users or config.json files have to change. "None" if nothing. -->

None

## Screenshots

<!-- For visible UI changes: before and after. Crop out names, email
addresses, hostnames, Wi-Fi networks and notifications. -->

## How to test

<!-- Steps a reviewer can follow on a ModernOS install or VM. -->

1.

## Checklist

- [ ] Branch is based on `dev` (`hotfix/` branches: on `main`)
- [ ] `scripts/ci-check.sh` passes
- [ ] New UI strings use `I18n.t()` and exist in `en.json` and `de.json`
- [ ] Docs are updated where behaviour changed
- [ ] No personal data, tokens or keys in the code, logs or screenshots
