#!/usr/bin/env bash
# Build the ZIP uploaded to the OpenAI plugin portal (platform.openai.com/plugins,
# Create plugin -> With MCP).
#
# The portal no longer accepts skills-only submissions, so the package declares
# the public docs MCP server (https://docs.goldsky.com/mcp, Streamable HTTP, no
# auth, read-only search tools) in a root mcp.json, converted to the portable
# format. The portal rejects lifecycle
# hooks, so the package is: the root Agent Plugins manifest, mcp.json, skills/,
# the logo, and the policy files. No hooks/, commands/, agents/, or host manifests.
# auth-setup already covers "set it up and help me get started", so it is the
# onboarding skill in place of commands/get-started.md.
#
# The skills install and run the local Goldsky CLI, so the package sets
# requires_local_executor (listed as Desktop only).
#
# Usage: npm run build:openai   # writes dist/goldsky-openai-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(jq -r .version package.json)
out="dist/goldsky-openai-$version.zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/goldsky/assets" dist
cp -R skills "$stage/goldsky/skills"
cp assets/logo.png "$stage/goldsky/assets/logo.png"
cp LICENSE PRIVACY.md TERMS.md SECURITY.md "$stage/goldsky/"

# The repo's mcp.json uses Cursor's "type": "http". The portable format the portal
# reads needs its schema and "streamable-http", or the portal sees no MCP server.
jq '{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  mcpServers: (.mcpServers | map_values({ type: "streamable-http", url }))
}' mcp.json > "$stage/goldsky/mcp.json"

jq --arg version "$version" '{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  name: .name,
  version: $version,
  description: .description,
  author: { name: "Goldsky", url: "https://goldsky.com" },
  homepage: .homepage,
  repository: .repository,
  license: .license,
  keywords: .keywords,
  extensions: {
    "com.openai": {
      requires_local_executor: true,
      onboardingSkill: "./skills/auth-setup/SKILL.md",
      interface: {
        displayName: .displayName,
        shortDescription: "Onchain data pipelines + RPC",
        longDescription: (.description + "\n\nThe skills install the Goldsky CLI with npm into user-writable directories and sign in through `goldsky login` in the browser. Requires a desktop environment with Node.js and npm, and a Goldsky account, which can be created during login."),
        developerName: "Goldsky",
        category: "Developer Tools",
        capabilities: [
          "Build and deploy Turbo pipelines",
          "Build, deploy, and debug subgraphs",
          "Build Compose apps",
          "Set up Edge and Boost RPC endpoints",
          "Query wallet balances and transfers"
        ],
        websiteURL: .homepage,
        supportURL: .supportUrl,
        privacyPolicyURL: .privacyPolicyUrl,
        termsOfServiceURL: .termsOfServiceUrl,
        defaultPrompt: [
          "Set up Goldsky and help me get started",
          "Stream USDC transfers on Base into my Postgres database",
          "Why is my Goldsky subgraph not syncing?"
        ],
        logo: "./assets/logo.png"
      }
    }
  }
}' .claude-plugin/plugin.json > "$stage/goldsky/plugin.json"

rm -f "$out"
(cd "$stage" && zip -qrX "$OLDPWD/$out" goldsky)
echo "Wrote $out"
