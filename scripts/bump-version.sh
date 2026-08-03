#!/usr/bin/env bash
# Bump the plugin version and sync it across every host manifest.
# Run this whenever you change anything under skills/ — CI enforces it on PRs,
# because Claude Code / Cursor plugin users only receive updates when the
# plugin `version` changes. Then commit the four modified manifest files.
#
# Usage:
#   npm run bump              # patch (default): 1.2.3 -> 1.2.4
#   npm run bump -- minor     # minor:           1.2.3 -> 1.3.0
#   npm run bump -- major     # major:           1.2.3 -> 2.0.0
# (or call ./scripts/bump-version.sh [patch|minor|major] directly)
set -euo pipefail
cd "$(dirname "$0")/.."

level="${1:-patch}"
current=$(jq -r .version package.json)

case "$level" in
  major) new=$(echo "$current" | awk -F. -v OFS=. '{$1 += 1; $2 = 0; $3 = 0; print}') ;;
  minor) new=$(echo "$current" | awk -F. -v OFS=. '{$2 += 1; $3 = 0; print}') ;;
  patch) new=$(echo "$current" | awk -F. -v OFS=. '{$3 += 1; print}') ;;
  *) echo "Unknown bump level '$level'. Use: patch (default) | minor | major" >&2; exit 1 ;;
esac

for f in package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json .claude-plugin/marketplace.json; do
  # -i.bak works on both GNU (Linux) and BSD (macOS) sed; drop the backup after
  sed -i.bak -E "s/\"version\": \"[0-9]+\.[0-9]+\.[0-9]+\"/\"version\": \"$new\"/" "$f"
  rm -f "$f.bak"
done

echo "Bumped $current -> $new ($level) across all manifests. Commit:"
echo "  package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json .claude-plugin/marketplace.json"
