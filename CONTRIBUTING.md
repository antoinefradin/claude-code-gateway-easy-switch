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

## 6. CI

The following must pass on every PR:

- **Tests** — `bash tests/e2e.sh`
- **Shell** — `shellcheck ccgs.sh` (install via `brew install shellcheck` or
  `apt install shellcheck`)
