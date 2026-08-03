#!/usr/bin/env bash
# Patch-bump the plugin version and sync it across every host manifest.
# Run this whenever you change anything under skills/ — CI enforces it on PRs,
# because Claude Code / Cursor plugin users only receive updates when the
# plugin `version` changes. Then commit the four modified manifest files.
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(jq -r .version package.json)
new=$(echo "$current" | awk -F. -v OFS=. '{$3 += 1; print}')

for f in package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json .claude-plugin/marketplace.json; do
  # -i.bak works on both GNU (Linux) and BSD (macOS) sed; drop the backup after
  sed -i.bak -E "s/\"version\": \"[0-9]+\.[0-9]+\.[0-9]+\"/\"version\": \"$new\"/" "$f"
  rm -f "$f.bak"
done

echo "Bumped $current -> $new across all manifests. Commit:"
echo "  package.json .claude-plugin/plugin.json .cursor-plugin/plugin.json .claude-plugin/marketplace.json"
