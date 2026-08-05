# Contributing

This project follows GitHub flow with feature branches, pull requests, and peer
review. The rules below are prescriptive.

## 1. Branching

- Branch off `main`.
- Name: `<type>/<short-desc>`.
- `<type>` must be one of the Conventional Commits types:
  `feat`, `fix`, `docs`, `chore`, `refactor`, `perf`, `test`, `build`, `ci`,
  `revert`.
- Kebab-case, lowercase, ASCII only.
- Examples:
  - `feat/session-mode`
  - `fix/settings-json-race`
  - `docs/litellm-setup`

## 2. Commits

- Follow [Conventional Commits](https://www.conventionalcommits.org/):
  `<type>(<scope>): <subject>`.
- `scope` is optional. Use a functional area when it adds clarity (`cli`,
  `install`, `models`, `docs`).
- Subject: imperative mood, ≤72 chars, no trailing period, **English**.
- Use `!` for breaking changes (`feat(cli)!: …`) or a `BREAKING CHANGE:` footer.
- Body optional; explain **why** when non-obvious.
- Do **not** add `Co-Authored-By` or any AI-attribution trailers.
- Clean up noise commits before pushing. Use `git commit --fixup <sha>` +
  `git rebase -i --autosquash`.

## 3. Pull Requests

- **PR title also follows Conventional Commits.** The PR title becomes the
  merge commit message on `main`.
- Description covers: **What / Why / How to test**.
- Keep PRs small and scoped. Avoid drive-by refactors.
- Open as **Draft** for early feedback; mark ready when CI is green.

## 4. Review

- **1 approval required.**
- Authors must respond to every comment and mark each conversation as
  **resolved** once addressed.
- New pushes after approval dismiss prior reviews. Re-request review.

## 5. Merging and rebasing

### Merging

- **The PR author merges** once:
  1. 1 approval
  2. CI green
  3. All conversations resolved
  4. Branch up-to-date with `main`
- **Merge method: merge commit only.** No squash, no rebase-merge.

### Rebasing

- Keep branches **rebased** onto `main` — never `git merge main` into a
  feature branch.
- Use `git push --force-with-lease`, never plain `--force`.
- Do not rebase while a review is in progress.

## 6. Versioning & releases

Releases are **automated** — you never bump the version by hand.

- Merging a PR into `main` triggers `.github/workflows/release.yml`, which runs
  `./release.sh --auto --ci`. It reads the commits since the last `vX.Y.Z` tag and
  cuts a new release.
- **Your commit types decide the version** ([SemVer](https://semver.org/)):
  - any `feat` commit → **minor** bump (`0.2.0` → `0.3.0`)
  - `fix` / other types → **patch** bump (`0.2.0` → `0.2.1`)
  - `!` or a `BREAKING CHANGE:` footer → **major** bump (`0.2.0` → `1.0.0`)
  - So write accurate types — they are the version, not just changelog fodder.
- **Website / docs / assets / workflow-only changes do not cut a CLI release.**
  A PR touching only `website/`, `docs/`, `assets/`, or `.github/` is skipped
  (the site publishes via the Pages workflow instead).
- **Do not hand-edit** `CCGS_VERSION` in `ccgs.sh`, the README version badge, or
  add `## [x.y.z]` headings to `CHANGELOG.md` — CI writes all three and pushes a
  `chore(release): vX.Y.Z [skip ci]` commit plus the tag. Changelog notes are
  generated from your commit subjects, which is another reason to keep them clear.
- Merge-commit-only merging (§5) is required for this to work: your branch's
  `feat:` / `fix:` commits stay in `main`'s history so the release scan can see
  them.

## 7. CI

The following must pass on every PR:

- **Tests** — `bash tests/e2e.sh`
- **Shell** — `shellcheck ccgs.sh` (install via `brew install shellcheck` or
  `apt install shellcheck`)
