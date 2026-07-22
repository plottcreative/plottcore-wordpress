#!/usr/bin/env bash
#
# update-wordpress.sh
#
# Automates bumping the WordPress core version across:
#   - plottcore-wordpress-no-content (the WP zip package)
#   - plottcore-wordpress (the metapackage)
#
# Convention: Git tags use a v prefix (e.g. v7.0.1) while the version
# in composer.json remains bare (e.g. 7.0.1). This keeps SemVer clean
# in metadata while following standard Git tag practice.
#
# Usage:
#   ./update-wordpress.sh              # Auto-detect latest WP version
#   ./update-wordpress.sh 6.8.0        # Specify a version manually
#
# Prerequisites:
#   - git, gh, jq, curl, php must be installed
#   - Both repos must be cloned as siblings in the same parent directory
#   - You must have push access to both repos
#   - Working trees must be clean (uncommitted changes will abort)

set -euo pipefail

# --- Configuration ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PARENT_DIR="$(dirname "$SCRIPT_DIR")"
readonly NO_CONTENT_DIR="${PARENT_DIR}/plottcore-wordpress-no-content"
readonly META_DIR="${SCRIPT_DIR}" # This repo (plottcore-wordpress)
readonly ORG="plottcreative"

# --- Helpers ---
info()    { printf "\n\033[1;34m%s\033[0m\n" "$*"; }
success() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
error()   { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
warn()    { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }

# Build the v-prefixed tag name from a bare version string.
make_tag() { echo "v$1"; }

# --- Determine target version ---
if [ -n "${1:-}" ]; then
    NEW_VERSION="$1"
    info "Using specified version: $NEW_VERSION"
else
    info "Fetching latest WordPress version..."
    NEW_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | php -r "echo json_decode(file_get_contents('php://stdin'))->offers[0]->version;")
    info "Latest WordPress version: $NEW_VERSION"
fi

NEW_TAG="$(make_tag "$NEW_VERSION")"

# --- Get current version ---
CURRENT_VERSION=$(php -r "echo json_decode(file_get_contents('${META_DIR}/composer.json'))->version;")
info "Current package version: $CURRENT_VERSION"

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
    success "Already at version $NEW_VERSION. Nothing to do."
    exit 0
fi

info "Updating from $CURRENT_VERSION → $NEW_VERSION"
info "Tag: $NEW_TAG"

# --- Verify repos exist ---
[ -d "$NO_CONTENT_DIR/.git" ] || error "plottcore-wordpress-no-content not found at $NO_CONTENT_DIR"
[ -d "$META_DIR/.git" ]       || error "plottcore-wordpress not found at $META_DIR"

# --- Guard: check for existing tags ---
if git --git-dir "$NO_CONTENT_DIR/.git" rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    error "Tag $NEW_TAG already exists in plottcore-wordpress-no-content. Delete it first or bump the version."
fi
if git --git-dir "$META_DIR/.git" rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    error "Tag $NEW_TAG already exists in plottcore-wordpress. Delete it first or bump the version."
fi

# --- Guard: check for bare (unprefixed) version tags that could conflict ---
if git --git-dir "$NO_CONTENT_DIR/.git" rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    warn "Bare tag '$NEW_VERSION' exists in no-content repo — the old convention. The new '$NEW_TAG' tag will sit alongside it."
fi
if git --git-dir "$META_DIR/.git" rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    warn "Bare tag '$NEW_VERSION' exists in metapackage repo — the old convention. The new '$NEW_TAG' tag will sit alongside it."
fi

# --- Guard: check for uncommitted or unpushed work ---
check_clean() {
    local dir="$1" name="$2"
    cd "$dir"
    if ! git diff-index --quiet HEAD --; then
        error "$name has uncommitted changes. Commit or stash them first."
    fi
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main 2>/dev/null || echo '')" ]; then
        warn "$name has unpushed commits (ahead of origin/main). Will push them with the tag."
    fi
}
check_clean "$NO_CONTENT_DIR" "plottcore-wordpress-no-content"
check_clean "$META_DIR" "plottcore-wordpress"

# --- Step 1: Update plottcore-wordpress-no-content ---
info "Updating plottcore-wordpress-no-content..."

cd "$NO_CONTENT_DIR"
git checkout main

# Update dist URL and version together
WP_DIST_URL="https://wordpress.org/wordpress-${NEW_VERSION}-no-content.zip"
php -r "
    \$json = json_decode(file_get_contents('composer.json'), true);
    \$json['version'] = '$NEW_VERSION';
    \$json['dist']['url'] = '$WP_DIST_URL';
    file_put_contents('composer.json', json_encode(\$json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . \"\n\");
"

git add composer.json
git commit -m "Bump WordPress to $NEW_VERSION"
git tag -a "$NEW_TAG" -m "WordPress $NEW_VERSION"
git push origin main --tags
success "plottcore-wordpress-no-content updated and tagged $NEW_TAG"

# --- Step 2: Update plottcore-wordpress (metapackage) ---
info "Updating plottcore-wordpress..."

cd "$META_DIR"
git checkout main
git pull origin main

# Bump both the dependency version and the package version
php -r "
    \$json = json_decode(file_get_contents('composer.json'), true);
    \$json['require']['plott/plottcore-wordpress-no-content'] = '$NEW_VERSION';
    \$json['version'] = '$NEW_VERSION';
    file_put_contents('composer.json', json_encode(\$json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . \"\n\");
"

git add composer.json
git commit -m "Bump WordPress to $NEW_VERSION"
git tag -a "$NEW_TAG" -m "WordPress $NEW_VERSION"
git push origin main --tags
success "plottcore-wordpress updated and tagged $NEW_TAG"

# --- Step 3: Create GitHub releases ---
info "Creating GitHub releases..."

gh release create "$NEW_TAG" \
    --repo "$ORG/plottcore-wordpress-no-content" \
    --title "WordPress $NEW_VERSION" \
    --notes "Bumped WordPress core to $NEW_VERSION" \
    2>/dev/null && success "Release created for plottcore-wordpress-no-content" || warn "Release may already exist or gh auth issue — check manually"

gh release create "$NEW_TAG" \
    --repo "$ORG/plottcore-wordpress" \
    --title "WordPress metapackage $NEW_VERSION" \
    --notes "Bumped WordPress core to $NEW_VERSION. Repman will sync and Renovate will create PRs in client projects." \
    2>/dev/null && success "Release created for plottcore-wordpress" || warn "Release may already exist or gh auth issue — check manually"

# --- Done ---
success "WordPress updated to $NEW_VERSION across all packages!"
info "Next steps:"
echo "  1. Wait for Repman to sync (usually within minutes)"
echo "  2. Renovate will create PRs in client projects automatically"
echo "  3. Review and merge those PRs"
echo ""
echo "  Tags created:  $NEW_TAG (both repos)"
echo "  Composer ver:  $NEW_VERSION (both repos)"
