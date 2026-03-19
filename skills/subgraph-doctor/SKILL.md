---
name: subgraph-doctor
description: "Diagnose and fix broken Goldsky subgraphs interactively. Use whenever the user has a specific subgraph that is misbehaving — stalled indexing, error state, not syncing, 524 timeout errors, store errors, mapping failures, subgraph paused unexpectedly, slow sync progress, GraphQL endpoint returning stale data, or any symptom where a deployed subgraph is not working correctly. Runs goldsky subgraph log and list commands, identifies root cause, and offers fixes. For looking up CLI syntax or error message definitions WITHOUT an active problem, use /subgraph-monitor-debug instead. For deploying new subgraphs, use /subgraph-builder."
---

# Subgraph Doctor

## Boundaries

- Diagnose and fix EXISTING subgraph problems interactively.
- Do not build new subgraphs — that belongs to `/subgraph-builder`.
- Do not serve as a command reference. If the user only needs CLI syntax or error pattern lookup, use `/subgraph-monitor-debug` or `/subgraph-lifecycle`.

Systematically identify and resolve subgraph issues by following a structured diagnostic workflow.

## Mode Detection

Before running any commands, check if you have the `Bash` tool available:

- **If Bash is available** (CLI mode): Execute commands directly and parse output.
- **If Bash is NOT available** (reference mode): Output commands for the user to run. Ask them to paste the output back so you can analyze it.

## Diagnostic Workflow

Follow these steps in order. Do not skip steps — each builds on the previous one.

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

- **If logged in:** Note the current project and continue.
- **If not logged in:** Tell the user they need to authenticate. Use the `/auth-setup` skill for guidance. Do not proceed until auth is confirmed.

### Step 2: Identify the Subgraph

Run `goldsky subgraph list` to show all subgraphs.

Ask the user which subgraph they want to diagnose. If they already named one, confirm it exists in the list.

Note the subgraph's current status (Indexing, Synced, Paused, Error).

### Step 3: Analyze Subgraph Status

Based on the status:

- **Indexing** — Subgraph is active but may be slow or producing wrong data. Check sync progress and logs. Proceed to Step 4.
- **Synced** — Subgraph is caught up. If user reports issues, check data quality or endpoint access. Proceed to Step 4.
- **Error** — Subgraph has failed. Most common case. Proceed to Step 4 for log analysis.
- **Paused** — Subgraph was manually paused or auto-paused due to stalling. Ask if they want to investigate the cause before resuming.

### Step 4: Examine Logs

Run `goldsky subgraph log <name>/<version> 2>&1` to get recent logs.

Analyze the output for known error patterns. Reference the error patterns in `/subgraph-monitor-debug`, including:

- **Mapping errors** — handler crashes, null access, type mismatches
- **Store errors** — entity conflicts, duplicate IDs, schema mismatches
- **Deployment errors** — IPFS timeouts, build failures, graft issues
- **RPC errors** — upstream node issues (usually transient)
- **Stall indicators** — no progress on block processing

### Step 5: Check Configuration (if applicable)

If logs show configuration-related errors:

- Verify the subgraph exists: `goldsky subgraph list <name>`
- Check if it's the right project: `goldsky project list`
- For instant subgraphs, check for ABI/column conflicts
- For source code subgraphs, check event signatures match the deployed contract

### Step 6: Provide Diagnosis

Present your findings in this format:

```
## Diagnosis

**Subgraph:** [name/version]
**Status:** [status]
**Issue:** [one-line summary]

**Root cause:**
[Detailed explanation of what's wrong]

**Evidence:**
- [Log line or observation 1]
- [Log line or observation 2]

**Recommended fix:**
1. [Step 1]
2. [Step 2]

**Prevention:**
[How to avoid this in the future]
```

### Step 7: Offer to Fix

If the fix involves CLI commands, offer to execute them. Always confirm with the user before making changes.

Common fixes:

- **Resume a paused subgraph:**
  ```bash
  goldsky subgraph start <name>/<version>
  ```

- **Redeploy with fixes:**
  ```bash
  goldsky subgraph deploy <name>/<new-version> --path .
  ```

- **Redeploy instant subgraph:**
  ```bash
  goldsky subgraph deploy <name>/<new-version> --from-abi config.json
  ```

- **Delete and start fresh:**
  ```bash
  goldsky subgraph delete <name>/<version>
  goldsky subgraph deploy <name>/<version> --path .
  ```

- **Remove graft issues:**
  ```bash
  goldsky subgraph deploy <name>/<new-version> --from-ipfs-hash <hash> --remove-graft
  ```

## Important Rules

- Never guess at the problem. Always check logs and status first.
- If you're unsure, say so and suggest what additional information would help.
- Always ask before running destructive commands (delete).
- If the issue is a handler/mapping bug, the user needs to fix their code and redeploy a new version.
- For stalled subgraphs that were auto-paused, fix the underlying issue before resuming.
- If the issue is beyond what the CLI can diagnose, suggest contacting Goldsky support at support@goldsky.com with the specific error messages.

## Related

- **`/subgraph-monitor-debug`** — CLI command reference and error pattern lookup
- **`/subgraph-lifecycle`** — Pause, start, delete, tag commands
- **`/subgraph-builder`** — Build and deploy new subgraphs
- **`/subgraph-config`** — Configuration reference
- **`/auth-setup`** — CLI authentication
