---
name: mirror-doctor
description: "Diagnose and fix broken Goldsky Mirror pipelines. Use this skill whenever a user has a Mirror pipeline that is failing, stuck, terminated, won't start, is in a restart loop, or is blocked by an in-flight request. Also use when the user mentions a specific Mirror pipeline name alongside a problem — even if they don't say 'mirror' explicitly, if they're using `goldsky pipeline` commands (not `goldsky turbo`), this is the right skill. Runs CLI commands directly to check status, read errors, identify root cause, and apply fixes. For YAML syntax or config reference, use /mirror instead. For turbo pipeline problems, use /turbo-doctor instead."
---

# Mirror Pipeline Doctor

Diagnose and fix existing Mirror pipeline problems by running CLI commands, identifying root causes, and executing fixes.

## Boundaries

- Diagnose and fix EXISTING Mirror pipeline problems.
- Do not build new pipelines — use `/mirror` for config reference or `/turbo-builder` for new Turbo pipelines.
- Do not serve as a command reference — use `/mirror` for CLI syntax and flag lookups.
- Do not handle Turbo pipelines — use `/turbo-doctor` for `goldsky turbo` problems.
- Do not create secrets — use `/secrets` for credential management. But DO check whether secrets exist as part of diagnosis.

## Diagnostic Workflow

Follow these steps in order. Each step builds on the previous one.

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to confirm the user is logged in.

- **If logged in:** Note the project name and continue.
- **If not logged in:** Direct the user to `/auth-setup`. Do not proceed until auth works.

### Step 2: Identify the Pipeline

Run `goldsky pipeline list --include-runtime-details 2>&1` to list all Mirror pipelines with their status.

If the user already named a pipeline, confirm it exists in the list. If not, show the list and ask which pipeline they want to diagnose.

Note both the **desired status** (ACTIVE, INACTIVE, PAUSED) and the **runtime status** (STARTING, RUNNING, FAILING, TERMINATED) — Mirror pipelines have both, and the combination tells the story.

### Step 3: Triage by Status

The desired + runtime status combination determines the diagnostic path:

| Desired | Runtime | Meaning | Action |
|---------|---------|---------|--------|
| ACTIVE | RUNNING | Healthy — pipeline is processing data | Ask user what symptom they're seeing. Proceed to Step 4. |
| ACTIVE | STARTING | Pipeline is initializing | Ask how long. If >10 min, proceed to Step 4. |
| ACTIVE | FAILING | Pipeline is encountering errors but hasn't terminated yet | Proceed to Step 4 immediately — this is time-sensitive. |
| ACTIVE | TERMINATED | **Most common failure.** Pipeline wanted to run but crashed. | Proceed to Step 4. |
| PAUSED | TERMINATED | User paused the pipeline (snapshot was taken). | Ask if they want to resume: `goldsky pipeline start <name> --from-snapshot last` |
| INACTIVE | TERMINATED | User stopped the pipeline (no snapshot). | Ask if they want to start: `goldsky pipeline start <name>` |

**ACTIVE + TERMINATED is the most common case.** The pipeline's desired status is ACTIVE (it should be running) but the runtime has terminated due to an error. Focus the diagnosis here.

### Step 4: Gather Diagnostic Data

Run these commands to understand what went wrong:

```bash
# Get error details and runtime metrics
goldsky pipeline monitor <name> 2>&1

# Check for in-flight requests blocking operations
goldsky pipeline monitor <name> --update-request 2>&1

# Get the pipeline definition to check for misconfig
goldsky pipeline get <name> --definition 2>&1

# Get pipeline info including version
goldsky pipeline info <name> 2>&1

# Check available snapshots
goldsky pipeline snapshots list <name> 2>&1
```

Run these in sequence and analyze the output before proceeding. The monitor output is the most important — it shows error messages, records received/written metrics, and runtime status transitions.

### Step 5: Match Error Patterns

Based on the diagnostic data, match against these known patterns:

#### Bad or Missing Secret

**Symptoms:** Pipeline terminates shortly after starting. Monitor shows credential or authentication errors.

**Verify:** Run `goldsky secret list 2>&1` and cross-reference with the `secret_name` values in the pipeline definition from Step 4.

**Fix:**
1. If the secret doesn't exist, direct the user to `/secrets` to create it.
2. If the secret exists but credentials are wrong, create a new secret (secrets are immutable — you create a replacement with the same name).
3. Restart: `goldsky pipeline restart <name> --from-snapshot last`

#### Sink Unreachable

**Symptoms:** Connection timeout, connection refused, or network errors in the monitor output. Pipeline may cycle between FAILING and TERMINATED.

**Common causes:**
- Firewall not allowing inbound from AWS us-west-2 (Mirror pipelines write from this region)
- Database is down or restarted
- Connection pool exhausted
- Wrong port or host in the secret

**Fix:**
1. Verify the sink is reachable from us-west-2.
2. Check that the secret has the correct host, port, and credentials.
3. Once connectivity is restored, restart: `goldsky pipeline restart <name> --from-snapshot last`

#### Resource Exhaustion

**Symptoms:** Pipeline runs for a while then terminates. Monitor may show high record counts or slow processing. Common during large backfills or pipelines with many sources/JOINs.

**Fix:**
1. Resize: `goldsky pipeline resize <name> <size>` — sizes are `s`, `m`, `l`, `xl`, `xxl`.
2. Start small and go up. `s` handles most workloads (up to 300K records/sec, ~8 subgraph sources). Use `l` or larger for big chain backfills or heavy JOINs.

#### In-Flight Request Blocking

**Symptoms:** User tries to update, delete, or restart the pipeline but gets "Cannot process request, found existing request in-flight."

**Diagnose:** `goldsky pipeline monitor <name> --update-request` — this shows what operation is in progress (usually a snapshot).

**Fix:**
1. If the in-flight operation is a snapshot that's making progress, wait for it.
2. If it's stuck or unwanted: `goldsky pipeline cancel-update <name>`
3. Then retry the original operation.

#### Stuck Snapshot

**Symptoms:** Pipeline can't be paused, updated, or restarted because a snapshot creation is taking too long or failing. The `--update-request` monitor shows snapshot progress stuck at a percentage.

**Fix:**
1. Cancel the stuck snapshot: `goldsky pipeline cancel-update <name>`
2. Restart without waiting for a new snapshot: `goldsky pipeline restart <name> --from-snapshot last`
3. If there's no usable snapshot: `goldsky pipeline restart <name> --from-snapshot none` (starts from scratch — warn the user this reprocesses data)

#### Transform SQL Error

**Symptoms:** Pipeline terminates with SQL-related error messages. Could be syntax errors, referencing a non-existent column, or type mismatches.

**Diagnose:** Check the pipeline definition (`goldsky pipeline get <name> --definition`) and look at the `transforms` section.

**Fix:**
1. Identify the SQL error from the monitor output.
2. Fix the SQL in the pipeline YAML file.
3. Validate: `goldsky pipeline validate <file.yaml>`
4. Reapply: `goldsky pipeline apply <file.yaml> --status ACTIVE --from-snapshot last`

Use `/mirror` for SQL transform syntax reference if needed.

#### Pipeline in Restart Loop

**Symptoms:** Pipeline repeatedly cycles through STARTING → FAILING → TERMINATED. Monitor shows the same error recurring.

**This is usually a symptom of another root cause** — bad secret, sink unreachable, or resource issues. The pipeline keeps trying to start but hits the same wall.

**Fix:**
1. Identify the underlying error from the monitor (it's usually one of the patterns above).
2. Fix the root cause first.
3. Then restart: `goldsky pipeline restart <name> --from-snapshot last`

#### Sink Downtime Cascade

**Symptoms:** Pipeline was running fine, then the sink (database) went down temporarily. Pipeline auto-retried, then restarted its writers, then eventually terminated.

**This is expected behavior** — Mirror handles transient sink errors automatically (retry batch → restart writers → fail after prolonged issues).

**Fix:**
1. Confirm the sink is back up and healthy.
2. Restart from the last snapshot: `goldsky pipeline restart <name> --from-snapshot last`
3. The pipeline will resume from where it left off, not reprocess everything.

### Step 6: Present Diagnosis

After identifying the issue, present findings clearly:

```
## Diagnosis

**Pipeline:** <name>
**Status:** <desired> + <runtime>
**Issue:** <one-line summary>

**Root cause:**
<What's wrong and why>

**Evidence:**
- <Error message or observation from monitor>
- <Relevant detail from pipeline definition>

**Recommended fix:**
1. <Step 1>
2. <Step 2>

**Prevention:**
<How to avoid this in the future, if applicable>
```

### Step 7: Execute Fix

Offer to run the fix commands directly. Always confirm with the user before executing:

- **Restart:** `goldsky pipeline restart <name> --from-snapshot last`
- **Resize:** `goldsky pipeline resize <name> <size>`
- **Cancel blocked operation:** `goldsky pipeline cancel-update <name>`
- **Restart from scratch:** `goldsky pipeline restart <name> --from-snapshot none` (warn: reprocesses data)
- **Reapply config:** `goldsky pipeline apply <file.yaml> --status ACTIVE --from-snapshot last`
- **Delete and recreate:** `goldsky pipeline delete <name> -f` then `goldsky pipeline apply <file.yaml> --status ACTIVE` (last resort)

After executing, verify recovery by running `goldsky pipeline monitor <name>` and watching for STARTING → RUNNING transition.

## Important Rules

- Always gather data before diagnosing. Never guess at the problem.
- Check both desired AND runtime status — the combination matters.
- Confirm with the user before running any destructive commands (delete, restart from scratch).
- `--from-snapshot last` preserves progress. `--from-snapshot none` starts over. Default to `last` unless there's a reason not to.
- Transient errors are auto-retried for up to 6 hours. Non-transient errors terminate immediately. If the pipeline terminated quickly after starting, it's likely a config issue (bad secret, wrong SQL), not a transient network blip.
- If the problem is beyond CLI diagnosis, suggest contacting support@goldsky.com with the pipeline name, error messages, and project ID.

## When Bash is Not Available

If you don't have the Bash tool, output the diagnostic commands for the user to run, but structure them clearly:

1. Give one command at a time.
2. Explain what to look for in the output.
3. Based on their description of the output, proceed with the diagnosis.

This is the fallback path — always prefer running commands directly when Bash is available.

## Related

- **`/mirror`** — Pipeline YAML configuration, CLI flag reference, sink setup
- **`/secrets`** — Create and manage sink credentials
- **`/auth-setup`** — CLI installation and authentication
- **`/turbo-doctor`** — Diagnose Turbo pipeline problems (not Mirror)
