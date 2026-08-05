#!/usr/bin/env bash
# release.sh — cut a new ccgs release
#
# Bumps the version in every place it lives, updates the changelog, commits,
# tags (vX.Y.Z), pushes, and (if `gh` is available) publishes a GitHub Release.
#
# Usage:
#   ./release.sh <x.y.z>          # explicit version, e.g. 0.3.0 (or v0.3.0)
#   ./release.sh --auto           # compute the next version from commit messages
#   ./release.sh --auto --ci      # non-interactive, for GitHub Actions
#   ./release.sh <...> --dry-run  # print actions without changing anything
#
# Auto mode (Conventional Commits) picks the bump size from the commits since the
# last vX.Y.Z tag: a `feat` subject → minor, `!` / `BREAKING CHANGE` → major,
# anything else → patch. If every changed path since the last tag is website /
# docs / assets / workflow only, no CLI release is cut (exit 0).
# Note: pre-1.0 (0.x) this keeps simple semver rules; breaking → major even though
# 0.x conventionally maps breaking to minor. Kept explicit for predictability.
#
# https://github.com/antoinefradin/claude-code-gateway-easy-switch
# MIT License

set -euo pipefail

# ─── Locate repo root ───────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# ─── Args ────────────────────────────────────────────────────────────────────────

NEW_VERSION=""
DRY_RUN=0
AUTO=0
CI_MODE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --auto)    AUTO=1 ;;
    --ci)      CI_MODE=1 ;;
    -h|--help)
      grep -E '^# ' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "✗ unknown option: $arg" >&2
      exit 1
      ;;
    *)
      if [[ -n "$NEW_VERSION" ]]; then
        echo "✗ unexpected argument: $arg" >&2
        exit 1
      fi
      NEW_VERSION="$arg"
      ;;
  esac
done

# --ci implies --auto (CI never types a version by hand).
[[ "$CI_MODE" -eq 1 ]] && AUTO=1

if [[ "$AUTO" -eq 0 && -z "$NEW_VERSION" ]]; then
  echo "usage: ./release.sh <x.y.z> | --auto [--ci] [--dry-run]" >&2
  exit 1
fi
if [[ "$AUTO" -eq 1 && -n "$NEW_VERSION" ]]; then
  echo "✗ --auto computes the version; do not also pass one ('$NEW_VERSION')" >&2
  exit 1
fi

TODAY="$(date +%F)"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ─── Read current version (source of truth) ─────────────────────────────────────────

CURRENT="$(grep -oE 'CCGS_VERSION="[^"]+"' ccgs.sh | cut -d'"' -f2)"
if [[ -z "$CURRENT" ]]; then
  echo "✗ could not read current CCGS_VERSION from ccgs.sh" >&2
  exit 1
fi

# ─── Determine NEW_VERSION ───────────────────────────────────────────────────────────

# Paths that are NOT part of the CLI package — a change touching only these does
# not warrant a ccgs release.
NON_CLI_RE='^(website|docs|assets|\.github)/'

if [[ "$AUTO" -eq 1 ]]; then
  LAST_TAG="$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true)"

  if [[ -n "$LAST_TAG" ]]; then
    RANGE="${LAST_TAG}..HEAD"
    if [[ -z "$(git rev-list "$RANGE")" ]]; then
      echo "✓ no commits since ${LAST_TAG} — nothing to release"
      exit 0
    fi
    CHANGED="$(git diff --name-only "$RANGE")"
    if [[ -n "$CHANGED" ]] && ! grep -qvE "$NON_CLI_RE" <<<"$CHANGED"; then
      echo "✓ only website/docs/assets/workflow files changed since ${LAST_TAG} — skipping CLI release"
      exit 0
    fi
  else
    # First tagged release: cover full history, base the bump off CURRENT.
    RANGE="HEAD"
    echo "! no prior vX.Y.Z tag — basing first release off CCGS_VERSION=$CURRENT"
  fi

  SUBJECTS="$(git log "$RANGE" --format='%s')"
  BODIES="$(git log "$RANGE" --format='%b')"

  if grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$SUBJECTS" || grep -q 'BREAKING CHANGE' <<<"$BODIES"; then
    BUMP="major"
  elif grep -qE '^feat(\([^)]*\))?:' <<<"$SUBJECTS"; then
    BUMP="minor"
  else
    BUMP="patch"
  fi

  IFS=. read -r MA MI PA <<<"$CURRENT"
  case "$BUMP" in
    major) MA=$((MA + 1)); MI=0; PA=0 ;;
    minor) MI=$((MI + 1)); PA=0 ;;
    patch) PA=$((PA + 1)) ;;
  esac
  NEW_VERSION="${MA}.${MI}.${PA}"
  echo "→ auto version: $CURRENT → $NEW_VERSION ($BUMP, from ${LAST_TAG:-<initial>}..HEAD)"
fi

# Normalize: accept 0.3.0 or v0.3.0, store bare version + vX.Y.Z tag.
NEW_VERSION="${NEW_VERSION#v}"
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "✗ version must be x.y.z (got '$NEW_VERSION')" >&2
  exit 1
fi
TAG="v${NEW_VERSION}"

# ─── 1. Preconditions ─────────────────────────────────────────────────────────────

if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ working tree not clean — commit or stash first" >&2
  exit 1
fi

# CI checks out a detached HEAD at the pushed main SHA, so skip the branch-name
# check there (the workflow trigger already guarantees we're releasing main).
if [[ "$CI_MODE" -eq 0 ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$BRANCH" != "main" ]]; then
    echo "✗ not on main (on '$BRANCH')" >&2
    exit 1
  fi
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "✗ tag $TAG already exists" >&2
  exit 1
fi
if [[ "$CURRENT" == "$NEW_VERSION" ]]; then
  echo "✗ version is already $NEW_VERSION" >&2
  exit 1
fi

echo "Releasing $CURRENT → $NEW_VERSION ($TAG)"

# ─── 2. Tests ──────────────────────────────────────────────────────────────────────

echo "→ running tests"
run bash tests/e2e.sh

# ─── 3. Build the CHANGELOG section ─────────────────────────────────────────────────

# In CI/auto mode, derive release notes from commit subjects since the last tag;
# otherwise leave a blank template for the author to fill in during the pause.
SECTION_FILE="$(mktemp)"
trap 'rm -f "$SECTION_FILE" ccgs.sh.bak README.md.bak CHANGELOG.md.tmp' EXIT

{
  printf '## [%s] — %s\n\n' "$NEW_VERSION" "$TODAY"
  if [[ "$AUTO" -eq 1 ]]; then
    added="$(git log "$RANGE" --format='%s'  | grep -E '^feat(\([^)]*\))?!?:' | sed -E 's/^[a-z]+(\([^)]*\))?!?: */- /' || true)"
    fixed="$(git log "$RANGE" --format='%s'  | grep -E '^fix(\([^)]*\))?!?:'  | sed -E 's/^[a-z]+(\([^)]*\))?!?: */- /' || true)"
    changed="$(git log "$RANGE" --format='%s' | grep -vE '^(feat|fix|chore\(release\))(\([^)]*\))?!?:' | sed -E 's/^[a-z]+(\([^)]*\))?!?: */- /' || true)"
    [[ -n "$added"   ]] && printf '### Added\n\n%s\n\n' "$added"
    [[ -n "$fixed"   ]] && printf '### Fixed\n\n%s\n\n' "$fixed"
    [[ -n "$changed" ]] && printf '### Changed\n\n%s\n\n' "$changed"
  else
    printf '### Added\n\n- \n\n### Changed\n\n- \n\n### Fixed\n\n- \n\n'
  fi
} > "$SECTION_FILE"

# ─── 4. Bump version in all three locations ─────────────────────────────────────────

echo "→ bumping ccgs.sh, README.md, CHANGELOG.md"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  [dry-run] ccgs.sh    CCGS_VERSION \"$CURRENT\" → \"$NEW_VERSION\""
  echo "  [dry-run] README.md  version-$CURRENT-blue → version-$NEW_VERSION-blue"
  echo "  [dry-run] CHANGELOG.md insert section:"
  sed 's/^/    | /' "$SECTION_FILE"
else
  # ccgs.sh — source of truth
  sed -i.bak "s/^readonly CCGS_VERSION=\".*\"/readonly CCGS_VERSION=\"${NEW_VERSION}\"/" ccgs.sh

  # README.md — shields.io badge
  sed -i.bak "s/version-${CURRENT}-blue/version-${NEW_VERSION}-blue/" README.md

  # CHANGELOG.md — insert the new section before the first existing version heading
  awk -v f="$SECTION_FILE" '
    !done && /^## \[[0-9]/ {
      while ((getline line < f) > 0) print line
      done = 1
    }
    { print }
  ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

  rm -f ccgs.sh.bak README.md.bak

  # Verify all three actually changed
  grep -q "CCGS_VERSION=\"${NEW_VERSION}\"" ccgs.sh   || { echo "✗ ccgs.sh bump failed" >&2; exit 1; }
  grep -q "version-${NEW_VERSION}-blue" README.md      || { echo "✗ README.md bump failed" >&2; exit 1; }
  grep -q "## \[${NEW_VERSION}\]" CHANGELOG.md          || { echo "✗ CHANGELOG.md bump failed" >&2; exit 1; }
fi

# Interactive pause to polish notes — skipped in CI and dry-run.
if [[ "$DRY_RUN" -eq 0 && "$CI_MODE" -eq 0 ]]; then
  echo "  edit CHANGELOG.md now if you want to polish the release notes, then press Enter…"
  read -r _
fi

# ─── 5. Commit, tag, push ───────────────────────────────────────────────────────────

if [[ "$CI_MODE" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
  git config user.name  "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

echo "→ committing, tagging $TAG, pushing"
run git add ccgs.sh README.md CHANGELOG.md
# '[skip ci]' keeps the release commit from re-triggering the release workflow.
run git commit -m "chore(release): ${TAG} [skip ci]"
run git tag -a "$TAG" -m "ccgs ${NEW_VERSION}"
if [[ "$CI_MODE" -eq 1 ]]; then
  run git push origin "HEAD:main" "$TAG"
else
  run git push origin main "$TAG"
fi

# ─── 6. GitHub Release ──────────────────────────────────────────────────────────────

if command -v gh >/dev/null 2>&1; then
  echo "→ creating GitHub Release"
  run gh release create "$TAG" \
    --title "ccgs ${NEW_VERSION}" \
    --notes "See [CHANGELOG.md](CHANGELOG.md) for details." \
    ccgs.sh
else
  echo "! gh CLI not found — skipping GitHub Release (tag $TAG was pushed)."
  echo "  Create it manually at: https://github.com/antoinefradin/claude-code-gateway-easy-switch/releases/new?tag=${TAG}"
fi

echo "✓ Released $TAG"
