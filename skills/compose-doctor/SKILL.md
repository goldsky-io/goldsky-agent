---
name: compose-doctor
description: "Diagnose and fix broken Goldsky Compose apps interactively. Triggers on: compose app in error state, crashlooping, not running, not processing tasks, cron not firing, HTTP trigger returning 500, onchain event listener missing events, wallet errors, gas sponsorship failures, 'No bundler provider available', manifest validation errors, bundling/esbuild failures, secret missing, 'You cannot use a smart wallet in local dev', 'Transaction Receipt failed with status'. Also use when the user mentions a Compose app name alongside a problem, even if they don't say 'compose' explicitly, if they're referring to `goldsky compose` commands (not `goldsky turbo` or `goldsky pipeline`). Runs `status`/`logs`/`secret list`/`wallet list` to identify root cause, and offers fixes. For building a new app from scratch, use /compose instead. For manifest field / CLI flag / API lookups without an active problem, use /compose-reference instead. Do NOT trigger on Turbo or Mirror pipeline problems."
---

# Compose Doctor

Diagnose and fix broken Compose apps. Workflow-oriented: we walk through auth → app identification → status → logs → secrets → wallets → manifest → diagnosis → fix.

## Boundaries

- Diagnose and fix EXISTING Compose apps interactively.
- Do not build new apps — use `/compose` for that.
- Do not serve as a CLI/manifest reference — use `/compose-reference`.
- For secrets creation/management mechanics, use `/secrets`. But DO check whether required secrets exist as part of diagnosis.
- Do not handle Turbo pipeline problems — use `/turbo-doctor`.

## Mode Detection

Before running any commands, check if you have the `Bash` tool available:

- **If Bash is available** (CLI mode): Execute commands directly and parse output.
- **If Bash is NOT available** (reference mode): Output commands for the user to run. Ask them to paste the output back so you can analyze it and provide recommendations.

## Diagnostic Workflow

### Step 1 — Verify Auth

`goldsky project list 2>&1`. If not logged in, use `/auth-setup`.

### Step 2 — Identify the App

`goldsky compose list`. Confirm the app exists and note its current status.

### Step 3 — Check Status

`goldsky compose status -n <app>` or `goldsky compose status -n <app> --json`.

Possible statuses: RUNNING, PAUSED, ERROR, STARTING, STOPPED, PROVISIONING. Decision tree:

- **RUNNING** but misbehaving → Step 4 (logs).
- **ERROR** → Step 4 (logs) is the fastest path.
- **PAUSED** → ask if intentional. `goldsky compose resume -n <app>` if not.
- **STARTING** for >5 minutes → Step 4. (Use `.updated_at` from `--json` output to compute how long.)
- **NOT_FOUND** → typo in the name? Or deployed to a different project / token.

### Step 4 — Examine Logs

`goldsky compose logs -n <app> --tail 200 --json 2>&1` (add `-f` to stream, `--level error,warn` to filter, `--since 1h` for a window, `--search <term>` for text match).

**How to match errors:** scan the full log text (NDJSON `.message` field when `--json` is set) for **exact substring** against the first column of the error table below. Log lines include a `dashboard_url` attribute pointing to the specific run in the dashboard — surface it to the user alongside the diagnosis.

### Step 5 — Check Secrets

If logs show missing-secret or auth errors:

```bash
goldsky compose secret list -n <app>
```

Cross-reference against the manifest's `secrets:` array. Use `/secrets` or `goldsky compose secret set` to fix.

### Step 6 — Check Wallets / Gas

If logs show wallet or transaction errors:

```bash
goldsky compose wallet list -n <app>
```

Check whether the error is:

- **"No bundler provider available for chain &lt;id&gt;"** → unsupported chain for gas sponsorship; either use a different chain or set `sponsorGas: false` and fund the EOA manually.
- **"You cannot use a smart wallet in local dev…"** → switch to `compose dev --fork-chains` or use a BYO EOA wallet locally.
- **"Transaction Receipt failed with status reverted"** → onchain revert. Open the `dashboard_url` from the log line — the run trace in the dashboard includes the decoded revert reason.

### Step 7 — Check Manifest

If logs show `Manifest validation failed: …`, the manifest was rejected at deploy time. Common causes are in the error table below.

### Step 8 — Diagnose + Fix

Present findings in this format:

```
## Diagnosis

**App:** <name>
**Status:** <status>
**Root cause:** <one-line explanation>
**Fix:** <one-line action, with exact command if possible>
**Verify:** <how to confirm it worked>
```

**If the fix is mechanical** (secret set, manifest edit, redeploy), execute it and re-run Steps 3–4 to verify. **If the fix requires user input** (contract revert reason, funding decision, API key rotation), surface the diagnosis and stop.

## Common Error Patterns

| Log / error message                                                                                                 | Cause                                                              | Fix                                                                 |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------- |
| `Manifest validation failed: api_version is required for deployment.`                                               | Missing `api_version` at top of compose.yaml                       | Add `api_version: stable` (or a semver)                             |
| `Manifest validation failed: api_version "<v>" is not valid.`                                                       | Bad version value                                                  | Use `stable`, `preview`, `canary`, or semver                        |
| `Project name must start with a letter…`                                                                            | Manifest `name` violates RFC 1123                                  | lowercase, letters/numbers/hyphens, letter-start                    |
| `<task>.name must start with a letter or underscore…`                                                               | Task name regex fail                                               | match `/^([a-zA-Z]\|_[a-zA-Z0-9])[a-zA-Z0-9_]*$/`                   |
| `<task>.triggers[N].authentication must be either 'auth_token' or 'none'`                                           | HTTP trigger auth wrong                                            | set to one of the two values                                        |
| `<task>.triggers[N].network must be in snake_case format`                                                           | onchain_event network name wrong case                              | `polygon_amoy`, `ethereum_mainnet` (snake_case)                     |
| `<task>.triggers[N].contract must be a valid EVM address`                                                           | bad 0x address                                                     | check checksum + 40 hex chars                                       |
| `<task>.triggers[N].ip_whitelist[N] must be a valid IP or CIDR`                                                     | malformed IP                                                       | fix format                                                          |
| `Secret names must be in SCREAMING_SNAKE_CASE format`                                                               | bad secret name                                                    | `MY_SECRET`, not `my-secret`                                        |
| `Secret name "<X>" in .env is reserved for the app's postgres database`                                             | secret clashes with hosted DB name (uppercased app name)           | rename the secret                                                   |
| `The following secrets are referenced in the manifest but are not set in your local .env file`                      | local dev missing secret                                           | add to `.env` or `goldsky compose secret set --env local`           |
| `Deploy blocked: required secrets are missing from cloud`                                                           | cloud secret missing                                               | `goldsky compose secret set` or `deploy --sync-env`                 |
| `Task bundling failed: <msg>`                                                                                       | esbuild compile error                                              | fix the TS error in the task                                        |
| `esbuild native binary crashed… architecture mismatch…`                                                             | arm/amd64 mismatch                                                 | rebuild image; `rm -rf ~/.cache/esbuild`                            |
| `You cannot use a smart wallet in local dev unless you use chain forking.`                                          | Smart wallet in plain `compose dev`                                | `compose dev --fork-chains` or switch to a BYO EOA                  |
| `No bundler provider available for chain <id>.`                                                                     | chain not supported by any bundler                                 | change chains, or set `sponsorGas: false`                           |
| `Chain <id> is not supported by Alchemy's bundler.`                                                                 | forced Alchemy on wrong chain                                      | unset `BUNDLER_PROVIDER` env override                               |
| `Transaction Receipt failed with status reverted`                                                                   | onchain revert                                                     | open `dashboard_url` for decoded revert reason                      |
| `Cannot deserialize params: chain <id> not found`                                                                   | reorg replay for a chain missing in viem/chains                    | update the CLI / switch chains                                      |
| `[Warning] onReorg is not supported for gas-sponsored transactions.`                                                | non-fatal warning                                                  | if reorg matters, switch to non-sponsored                           |
| `[Warning] The 'nonce' parameter is being ignored for gas-sponsored transactions.`                                  | passing `nonce` to sponsored send                                  | remove the nonce override                                           |

## Dashboard

Every app has a dashboard page: `https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>`. Every run has `…/runs/<run_id>`. When diagnosing, surface both links to the user.

## When Bash is Not Available

If you don't have the Bash tool, output the diagnostic commands for the user to run, but structure them clearly:

1. Give one command at a time.
2. Explain what to look for in the output.
3. Based on their description of the output, proceed with the diagnosis.

This is the fallback path — always prefer running commands directly when Bash is available.

## Important Rules

- Don't redeploy without reading logs first — the error is almost always already in there.
- Pause (not delete) before investigating. `goldsky compose pause` stops task execution without tearing down state.
- `--delete-database` on `compose delete` is irreversible — triple-check before running.
- If a deploy is stuck at "Provisioning infra…" for >5 minutes on a first deploy, that's normal. For redeploys, it should be fast.

## Related

- **`/compose`** — Build a new Compose app or explain what Compose is.
- **`/compose-reference`** — Manifest / CLI / TaskContext / codegen lookups.
- **`/secrets`** — Generic secret management.
- **`/auth-setup`** — Fix authentication.
