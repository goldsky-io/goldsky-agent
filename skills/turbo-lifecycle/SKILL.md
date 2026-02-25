---
name: turbo-lifecycle
description: Manage Turbo pipeline lifecycle - list, delete, pause, resume, restart pipelines. Use when listing pipelines, deleting pipelines, pausing/resuming, restarting, or managing pipeline state.
---

# Turbo Pipeline Lifecycle Management

List and delete Turbo pipelines.

## Triggers

Invoke this skill when the user:

- Says "list my pipelines", "show pipelines", or "what pipelines do I have"
- Wants to delete a pipeline
- Asks to clean up old pipelines
- Wants to see pipeline status
- Mentions `/turbo-lifecycle`

## Agent Instructions

When this skill is invoked, follow this interactive workflow:

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

**If output shows projects:** User is logged in. Continue to Step 2.

**If output contains "Make sure to run 'goldsky login'":**

1. Inform the user they need to authenticate
2. Invoke the `goldsky-auth-setup` skill
3. After successful login, return to this skill to continue

### Step 2: Determine the Action

Use AskUserQuestion to ask:

- **Question:** "What would you like to do?"
- **Options:**
  - "List all pipelines" (description: "See all pipelines in my project")
  - "Delete a pipeline" (description: "Remove a pipeline permanently")
  - "Pause a pipeline" (description: "Temporarily stop a running pipeline")
  - "Resume a pipeline" (description: "Restart a paused pipeline")
  - "Restart a pipeline" (description: "Restart pods, optionally clearing state")
  - "Clean up multiple pipelines" (description: "Delete several pipelines at once")

Based on their selection, follow the appropriate workflow below.

---

## Workflow: List All Pipelines

### Step 1: List Pipelines

```bash
goldsky turbo list
```

**Expected output:**

```
┌─────────────────────┬─────────┬─────────────────────┐
│ Name                │ Status  │ Created At          │
├─────────────────────┼─────────┼─────────────────────┤
│ my-pipeline         │ running │ 2024-01-15 10:30:00 │
│ test-pipeline       │ running │ 2024-01-14 09:00:00 │
└─────────────────────┴─────────┴─────────────────────┘
```

### Step 2: Provide Summary

```
## Your Pipelines

**Project:** [current project name]
**Total pipelines:** [count]

| Name | Status | Created |
| ---- | ------ | ------- |
| [name] | [status] | [date] |

**Next steps:**
- `/turbo-monitor-debug` - Monitor a specific pipeline
- `/turbo-lifecycle` - Delete or manage pipelines
```

---

## Workflow: Delete a Pipeline

### Step 1: Identify the Pipeline

If the user hasn't specified which pipeline, ask:

Use AskUserQuestion to ask:

- **Question:** "Which pipeline do you want to delete?"
- **Options:** (dynamically list pipelines from `goldsky turbo list`)

Or ask them to provide the pipeline name.

### Step 2: Confirm Deletion

**Important:** Deletion is permanent. Always confirm before deleting.

Show the user what will be deleted:

```
⚠️ WARNING: This will permanently delete the pipeline and all its data.

Pipeline to delete: [pipeline-name]

This action cannot be undone. The pipeline will stop processing and all checkpoints will be lost.

Do you want to proceed?
```

Wait for explicit confirmation.

### Step 3: Delete the Pipeline

**By name:**

```bash
goldsky turbo delete <pipeline-name>
```

**By YAML file:**

```bash
goldsky turbo delete -f <pipeline.yaml>
```

**Expected output:**

```
✓ Pipeline my-pipeline deleted
```

### Step 4: Verify Deletion

```bash
goldsky turbo list
```

Confirm the pipeline no longer appears in the list.

### Step 5: Provide Completion Summary

```
## Deletion Complete

**What was done:**
- ✓ Pipeline deleted: [pipeline-name]
- ✓ All checkpoints removed
- ✓ Pipeline no longer processing

**Note:** If you had sinks writing to databases, the data already written remains in those databases.

**Next steps:**
- `/turbo-pipelines` - Deploy a new pipeline
- `/turbo-lifecycle` - Manage other pipelines
```

---

## Workflow: Clean Up Multiple Pipelines

### Step 1: List All Pipelines

```bash
goldsky turbo list
```

Show the user all pipelines.

### Step 2: Identify Pipelines to Delete

Ask the user which pipelines they want to delete. They can:

- Provide a list of names
- Describe a pattern (e.g., "all test pipelines")

### Step 3: Confirm Batch Deletion

Show all pipelines that will be deleted:

```
⚠️ WARNING: This will permanently delete the following pipelines:

1. test-pipeline-1
2. test-pipeline-2
3. old-experiment

This action cannot be undone.

Do you want to proceed with deleting all 3 pipelines?
```

Wait for explicit confirmation.

### Step 4: Delete Each Pipeline

Delete pipelines one by one:

```bash
goldsky turbo delete test-pipeline-1
goldsky turbo delete test-pipeline-2
goldsky turbo delete old-experiment
```

### Step 5: Verify Cleanup

```bash
goldsky turbo list
```

Confirm deleted pipelines no longer appear.

### Step 6: Provide Completion Summary

```
## Cleanup Complete

**What was done:**
- ✓ Deleted: test-pipeline-1
- ✓ Deleted: test-pipeline-2
- ✓ Deleted: old-experiment

**Remaining pipelines:** [count]

**Next steps:**
- `/turbo-pipelines` - Deploy new pipelines
- `/turbo-lifecycle` - Continue managing pipelines
```

---

## Prerequisites

- [ ] Goldsky CLI installed
- [ ] Turbo CLI extension installed
- [ ] Logged in (`goldsky login`)

## Quick Reference

| Action             | Command                                           |
| ------------------ | ------------------------------------------------- |
| List all pipelines | `goldsky turbo list`                              |
| Delete by name     | `goldsky turbo delete <pipeline-name>`            |
| Delete by YAML     | `goldsky turbo delete -f <pipeline.yaml>`         |
| Pause pipeline     | `goldsky turbo pause <pipeline-name>`             |
| Resume pipeline    | `goldsky turbo resume <pipeline-name>`            |
| Restart pipeline   | `goldsky turbo restart <pipeline-name>`           |
| Restart fresh      | `goldsky turbo restart <pipeline-name> --clear-state` |

## Pipeline States

| State    | Description                                |
| -------- | ------------------------------------------ |
| running  | Pipeline is actively processing data       |
| starting | Pipeline is initializing                   |
| paused   | Pipeline is paused (replicas set to 0)     |
| stopped  | Pipeline is not running (manually stopped) |
| error    | Pipeline encountered an error              |

## Pause, Resume, and Restart

### Pause a Pipeline

Temporarily stop processing without deleting:

```bash
goldsky turbo pause <pipeline-name>
# or by YAML:
goldsky turbo pause -f <pipeline.yaml>
```

This sets deployment replicas to 0, preserving all state for later resumption.

### Resume a Pipeline

Restore a paused pipeline to its running state:

```bash
goldsky turbo resume <pipeline-name>
# or by YAML:
goldsky turbo resume -f <pipeline.yaml>
```

> You can only resume a **paused** pipeline. Attempting to resume an already running pipeline returns an error.

### Restart a Pipeline

Trigger a pod restart for a running or paused pipeline:

```bash
goldsky turbo restart <pipeline-name>
```

To clear all checkpoints and reprocess from the beginning:

```bash
goldsky turbo restart <pipeline-name> --clear-state
```

> **Restart vs Resume:** Use `resume` to restore a paused pipeline without restarting pods. Use `restart` when you need a fresh pod restart (e.g., after configuration changes or to recover from issues). Restart is **not supported** for Job-mode pipelines — use `delete` + `apply` instead.

---

## Important Notes

### Deletion is Permanent

- All checkpoints are lost
- Pipeline configuration is removed
- Cannot be undone

### Data in Sinks is Preserved

- Data already written to PostgreSQL, ClickHouse, etc. remains
- Only the pipeline itself is deleted
- You may need to manually clean up sink data if desired

### Checkpoints and Restarts

- Deleting a pipeline removes its checkpoints
- If you recreate a pipeline with the same name, it starts fresh
- To preserve checkpoints, use `goldsky turbo apply` to update instead of delete/recreate

### Project Scope

- `goldsky turbo list` shows pipelines in your current project only
- Use `goldsky project list` to see available projects
- Pipelines are isolated per project

## Common Patterns

### Delete and Recreate

If you need to restart a pipeline from scratch:

1. Delete the existing pipeline:

   ```bash
   goldsky turbo delete my-pipeline
   ```

2. Deploy fresh:

   ```bash
   goldsky turbo apply my-pipeline.yaml
   ```

This resets all checkpoints and starts processing from the configured `start_at` position.

### Rename Instead of Delete

To keep checkpoints but change the pipeline name:

1. Update the `name` field in your YAML
2. Apply the new configuration:

   ```bash
   goldsky turbo apply my-pipeline-v2.yaml
   ```

3. Delete the old pipeline:

   ```bash
   goldsky turbo delete my-pipeline
   ```

**Note:** This creates a new pipeline; checkpoints don't transfer between names.

### Clean Up Test Pipelines

For development, use a naming convention like `test-*` or `dev-*`:

```yaml
name: test-usdc-transfers # Easy to identify for cleanup
```

Then clean up all test pipelines when done.

## Troubleshooting

| Issue              | Action                                                |
| ------------------ | ----------------------------------------------------- |
| Pipeline not found | Check spelling; use `goldsky turbo list` to see names |
| Permission denied  | Verify you have Editor or Admin role in the project   |
| Delete failed      | Check logs for errors; pipeline may be in transition  |
| Wrong project      | Use `goldsky project list` to verify current project  |

### Error: Pipeline Not Found

```
Error: Pipeline 'wrong-name' not found
```

Fix: Run `goldsky turbo list` to see exact pipeline names. Names are case-sensitive.

### Error: Permission Denied

```
Error: Permission denied
```

Fix: You need Editor or Admin role. Contact a project Owner to upgrade your role.

## Related Skills

- **`/goldsky-auth-setup`** - **Invoke this if user is not logged in**
- **`/turbo-pipelines`** - Deploy new pipelines or modify configuration
- **`/turbo-monitor-debug`** - Monitor pipeline health and logs
