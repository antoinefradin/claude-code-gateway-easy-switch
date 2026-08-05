# Release Process

This guide explains how `ccgs` is versioned and released. Releases are **fully automated** — you never bump a version or write a changelog entry by hand. Your commit messages are the release.

See [CONTRIBUTING.md](../CONTRIBUTING.md) §6 for the short version; this document is the detailed reference.

---

## Overview

Every push to `main` (i.e. every merged PR) runs the [`Release` workflow](../.github/workflows/release.yml), which calls [`release.sh --auto --ci`](../release.sh). The script:

1. Reads the [Conventional Commits](https://www.conventionalcommits.org/) since the last `vX.Y.Z` tag.
2. Picks the [SemVer](https://semver.org/) bump from those commit types.
3. Skips entirely if only website / docs / assets / workflow files changed.
4. Runs the test suite.
5. Bumps the version in `ccgs.sh`, the `README.md` badge, and `CHANGELOG.md`.
6. Commits (`chore(release): vX.Y.Z [skip ci]`), tags `vX.Y.Z`, and pushes to `main`.
7. Publishes a GitHub Release with `ccgs.sh` attached.

```
merge PR ──▶ push to main ──▶ release.yml ──▶ release.sh --auto --ci
                                                     │
              ┌──────────────────────────────────────┤
              ▼                                       ▼
   only website/docs/assets/.github?          CLI code changed?
              │                                       │
         skip (exit 0)                    bump ─▶ commit ─▶ tag ─▶ GitHub Release
```

---

## How the version is chosen

The current version lives in exactly one place — `readonly CCGS_VERSION="x.y.z"` in [`ccgs.sh`](../ccgs.sh) — and is the source of truth. The bump is derived from the commit **types** since the last `vX.Y.Z` tag:

| Commit(s) since last tag | Bump  | Example         |
| ------------------------ | ----- | --------------- |
| any `feat`               | minor | `0.2.0 → 0.3.0` |
| `fix` / `docs` / `chore` / other | patch | `0.2.0 → 0.2.1` |
| `!` or `BREAKING CHANGE:` footer | major | `0.2.0 → 1.0.0` |

Precedence is highest-wins: one `feat!` in the range makes the whole release a major bump, regardless of the other commits.

> **Pre-1.0 note:** while on `0.x`, a breaking change bumps the **major** (`0.x → 1.0.0`), not the minor. This is stricter than the SemVer 0.x convention and is kept explicit for predictability.

This is why accurate commit types matter — they *are* the version, not just changelog text.

---

## When a release is skipped

A change that touches **only** these paths does not warrant a CLI release:

```
website/    docs/    assets/    .github/
```

If every changed path since the last tag matches that set, `release.sh` prints a skip message and exits `0` — no version bump, no tag. The website still publishes through its own GitHub Pages workflow.

> **First release exception:** when there is **no** prior `vX.Y.Z` tag yet, the skip check does not apply — the first release scans the full history and bases the bump off the current `CCGS_VERSION`. So the very first tagged release happens even if the triggering PR only touched docs or the website.

---

## What CI writes (do not hand-edit)

The release commit updates three files automatically. **Never edit these by hand:**

- `CCGS_VERSION` in [`ccgs.sh`](../ccgs.sh)
- the `version-x.y.z-blue` badge in [`README.md`](../README.md)
- the `## [x.y.z]` section in [`CHANGELOG.md`](../CHANGELOG.md)

Changelog notes are generated from your commit subjects, grouped into **Added** (`feat`), **Fixed** (`fix`), and **Changed** (everything else). Clear, well-typed subjects produce a clean changelog.

---

## Why merge commits are required

The merge method for PRs is **merge commit only** (see [CONTRIBUTING.md](../CONTRIBUTING.md) §5) — no squash, no rebase-merge. This is a hard requirement for the release scan: your branch's individual `feat:` / `fix:` commits must survive in `main`'s history so `release.sh` can read them and compute the right bump. Squashing would collapse them into a single subject and lose the signal.

---

## Running it manually

You normally never run `release.sh` yourself, but it is useful for previewing what CI will do:

```bash
# Preview the auto-computed bump without changing anything
./release.sh --auto --dry-run

# Cut a release with an explicit version (bypasses auto detection)
./release.sh 0.4.0

# What CI runs (non-interactive, on main only)
./release.sh --auto --ci
```

Notes:

- `--dry-run` prints every action (version bump, changelog section, git commands) without touching the repo.
- Outside CI, the script refuses to run unless you are on `main` with a clean working tree, and it pauses so you can polish `CHANGELOG.md` before committing.
- `--ci` implies `--auto` and skips the branch check (CI runs on a detached `main` SHA) and the interactive pause.
- `./release.sh --help` prints the full usage from the script header.

---

## Loop prevention

The release commit is tagged `chore(release): vX.Y.Z [skip ci]`. Two safeguards stop it from re-triggering the workflow:

1. The workflow's `if:` guard skips any commit whose message starts with `chore(release)`.
2. Pushes made with the default `GITHUB_TOKEN` do not trigger further workflow runs.

The `[skip ci]` marker is belt-and-suspenders on top of both.

---

## Troubleshooting

- **No release was cut after merging.** Check whether the PR touched only `website/` / `docs/` / `assets/` / `.github/` — those are skipped once a `vX.Y.Z` tag exists. Otherwise check the `Release` workflow run in the Actions tab.
- **Wrong bump size.** The bump follows commit types in the range. A stray `feat:` on a bugfix-only branch will produce a minor bump — fix the types before merging.
- **Version files look stale locally.** After a release, `git pull` on `main` to get CI's `chore(release)` commit and the new tag.
