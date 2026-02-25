---
name: turbo-monitor-debug
description: Monitor and debug Turbo pipelines. Use when viewing logs, inspecting live data, troubleshooting pipeline issues, or checking pipeline health.
---

# Monitor and Debug Turbo Pipelines

Monitor pipeline health, view logs, inspect live data, and troubleshoot issues.

## Triggers

Invoke this skill when the user:

- Says "check my pipeline", "view logs", or "debug the pipeline"
- Wants to see live data flowing through a pipeline
- Is troubleshooting pipeline errors or issues
- Asks "why isn't my pipeline working?"
- Wants to monitor pipeline health
- Mentions `/turbo-monitor-debug`

## Agent Instructions

When this skill is invoked, follow this interactive workflow:

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

**If output shows projects:** User is logged in. Continue to Step 2.

**If output contains "Make sure to run 'goldsky login'":**

1. Inform the user they need to authenticate
2. Invoke the `goldsky-auth-setup` skill
3. After successful login, return to this skill to continue

### Step 2: Identify the Pipeline

Use AskUserQuestion to ask:

- **Question:** "Which pipeline do you want to monitor?"
- **Options:**
  - "I know the pipeline name" (description: "I'll provide the name or YAML file")
  - "Show me my pipelines" (description: "List all pipelines in my project")

**If "I know the pipeline name":**

Ask for the pipeline name or YAML file path.

**If "Show me my pipelines":**

Run `goldsky turbo list` to show existing pipelines.

Ask which pipeline they want to monitor.

### Step 3: Determine the Goal

Use AskUserQuestion to ask:

- **Question:** "What do you want to do?"
- **Options:**
  - "View live data" (description: "See data flowing through the pipeline in real-time")
  - "Check logs" (description: "View pipeline execution logs")
  - "Debug an issue" (description: "Something isn't working right")
  - "Check overall health" (description: "Quick status check")

Based on their selection, follow the appropriate workflow below.

---

## Workflow: View Live Data

### Step 1: Open Live Inspect

```bash
goldsky turbo inspect <pipeline-name>
```

Or with a YAML file:

```bash
goldsky turbo inspect <pipeline.yaml>
```

This opens an interactive TUI (Terminal User Interface) showing live data.

### Step 2: Navigate the TUI

Explain the keyboard shortcuts:

**Navigation:**

| Key                     | Action                            |
| ----------------------- | --------------------------------- |
| `Tab` / `→`             | Next tab                          |
| `Shift+Tab` / `←`      | Previous tab                      |
| `1`-`9`                 | Jump to tab by number             |
| `j`/`k` / `↑`/`↓`     | Scroll up/down                    |
| `g` / `Home`            | Jump to top                       |
| `G` / `End`             | Jump to bottom                    |
| `Page Up` / `Page Down` | Scroll by page                    |
| Mouse wheel             | Scroll up/down                    |

**Search:**

| Key     | Action                  |
| ------- | ----------------------- |
| `/`     | Start search            |
| `Enter` | Execute search          |
| `n`     | Next match              |
| `N`     | Previous match          |
| `Esc`   | Clear search            |

**Actions:**

| Key            | Action                            |
| -------------- | --------------------------------- |
| `d`            | Toggle pipeline definition view   |
| `w`            | Open in web dashboard             |
| `e`            | Open in web editor                |
| `q` / `Ctrl+C` | Quit                             |

> **Tip:** Hold `Shift` while using the mouse to select and copy text from the TUI.

### Step 3: Filter to Specific Nodes

To focus on a specific source or transform:

```bash
goldsky turbo inspect <pipeline-name> -n <node-name>
```

View multiple nodes:

```bash
goldsky turbo inspect <pipeline-name> -n source1,transform1
```

### Step 4: Adjust Buffer Size

For more history, increase the buffer:

```bash
goldsky turbo inspect <pipeline-name> -b 50000
```

Default is 10,000 records.

---

## Workflow: Check Logs

### Step 1: View Recent Logs

```bash
goldsky turbo logs <pipeline-name>
```

Default shows last 10 lines.

### Step 2: Adjust Log Output

Show more lines:

```bash
goldsky turbo logs <pipeline-name> --tail 50
```

Show logs from last hour:

```bash
goldsky turbo logs <pipeline-name> --since 3600
```

Include timestamps:

```bash
goldsky turbo logs <pipeline-name> --timestamps
```

Follow logs in real-time:

```bash
goldsky turbo logs <pipeline-name> --follow
```

### Step 3: Analyze Log Output

Look for these patterns:

**Healthy indicators:**

- Processing messages with block numbers
- Checkpoint updates
- No error messages

**Warning indicators:**

- Slow processing messages
- Retry attempts
- Connection warnings

**Error indicators:**

- `Error:` or `ERROR` messages
- Stack traces
- Connection failures

---

## Workflow: Debug an Issue

### Step 1: Identify the Problem

Use AskUserQuestion to ask:

- **Question:** "What issue are you experiencing?"
- **Options:**
  - "No data flowing" (description: "Pipeline seems stuck or empty")
  - "Errors in logs" (description: "Seeing error messages")
  - "Wrong data output" (description: "Data doesn't look right")
  - "Sink not receiving data" (description: "Database/Kafka not getting updates")
  - "Pipeline keeps restarting" (description: "Unstable behavior")

Based on their selection, follow the appropriate debugging steps.

### Debugging: No Data Flowing

1. **Check pipeline status:**

   ```bash
   goldsky turbo list
   ```

   Verify the pipeline shows as running.

2. **Check the source configuration:**

   - If `start_at: latest`, pipeline only processes new data
   - If chain is slow, there may be no new data yet
   - Try `start_at: earliest` for testing (will process historical data)

3. **Check logs for errors:**

   ```bash
   goldsky turbo logs <pipeline-name> --tail 50
   ```

4. **Verify source dataset exists:**

   ```bash
   goldsky datasets list | grep <dataset-name>
   ```

### Debugging: Errors in Logs

1. **Get detailed logs:**

   ```bash
   goldsky turbo logs <pipeline-name> --tail 100 --timestamps
   ```

2. **Common error patterns:**

   | Error Pattern           | Likely Cause          | Fix                                    |
   | ----------------------- | --------------------- | -------------------------------------- |
   | `connection refused`    | Database unreachable  | Check network/firewall settings        |
   | `authentication failed` | Wrong credentials     | Update secret with correct credentials |
   | `secret not found`      | Missing secret        | Create secret with `goldsky-secrets`   |
   | `SQL syntax error`      | Invalid transform SQL | Fix SQL in YAML and redeploy           |
   | `duplicate key`         | Primary key collision | Ensure unique primary key in transform |

3. **If SQL error, validate the pipeline:**

   ```bash
   goldsky turbo validate <pipeline.yaml>
   ```

### Debugging: Wrong Data Output

1. **Inspect each stage of the pipeline:**

   ```bash
   # Check source data
   goldsky turbo inspect <pipeline-name> -n <source-name>

   # Check transform output
   goldsky turbo inspect <pipeline-name> -n <transform-name>
   ```

2. **Compare source vs transform:**

   ```bash
   goldsky turbo inspect <pipeline-name> -n source1,transform1
   ```

3. **Common issues:**

   - SQL `WHERE` clause too restrictive (filtering out all data)
   - Wrong column names in SQL
   - Type mismatches in transforms

### Debugging: Sink Not Receiving Data

1. **Verify the sink configuration:**

   - Check `from` field points to correct source/transform
   - Check `secret_name` matches an existing secret

2. **Check secret exists:**

   ```bash
   goldsky secret list
   ```

3. **Verify secret credentials:**

   ```bash
   goldsky secret reveal <secret-name>
   ```

   Test the credentials work outside Goldsky (e.g., `psql` for PostgreSQL).

4. **Check logs for sink errors:**

   ```bash
   goldsky turbo logs <pipeline-name> --tail 50 | grep -i error
   ```

### Debugging: Pipeline Keeps Restarting

1. **Check logs around restart time:**

   ```bash
   goldsky turbo logs <pipeline-name> --tail 100 --timestamps
   ```

2. **Common causes:**

   - Out of memory (try larger `resource_size`)
   - Infinite loop in TypeScript transform
   - Database connection pool exhaustion

3. **Try increasing resources:**

   Update `resource_size: m` or `resource_size: l` in YAML and redeploy.

---

## Workflow: Check Overall Health

### Step 1: List All Pipelines

```bash
goldsky turbo list
```

Check status column for each pipeline.

### Step 2: Quick Log Check

```bash
goldsky turbo logs <pipeline-name> --tail 20
```

Look for recent errors or warnings.

### Step 3: Verify Data Flow

```bash
goldsky turbo inspect <pipeline-name>
```

Confirm data is flowing through each node.

### Step 4: Provide Health Summary

After checking, provide a summary:

```
## Pipeline Health Check

**Pipeline:** [name]
**Status:** [running/stopped/error]

**Observations:**
- ✓ Pipeline is running
- ✓ Data flowing through sources
- ✓ Transforms processing correctly
- ✓ Sinks receiving data

**OR**

- ⚠ [Issue found - description]
- Action: [Recommended fix]
```

---

## Prerequisites

- [ ] Goldsky CLI installed
- [ ] Turbo CLI extension installed
- [ ] Logged in (`goldsky login`)
- [ ] At least one deployed pipeline

## Quick Reference

| Action                   | Command                                  |
| ------------------------ | ---------------------------------------- |
| List pipelines           | `goldsky turbo list`                     |
| View live data           | `goldsky turbo inspect <name>`           |
| Inspect specific node    | `goldsky turbo inspect <name> -n <node>` |
| View logs                | `goldsky turbo logs <name>`              |
| Follow logs              | `goldsky turbo logs <name> --follow`     |
| Logs with timestamps     | `goldsky turbo logs <name> --timestamps` |
| Last N lines             | `goldsky turbo logs <name> --tail N`     |
| Logs since N seconds ago | `goldsky turbo logs <name> --since N`    |

## Live Inspect TUI Shortcuts

| Key                     | Action               |
| ----------------------- | -------------------- |
| `Tab`/`→`, `Shift+Tab`/`←` | Next/prev tab    |
| `1`-`9`                 | Jump to tab number   |
| `j`/`k` / `↑`/`↓`     | Scroll               |
| `g`/`Home`, `G`/`End`  | Top/bottom           |
| `Page Up`/`Page Down`  | Scroll by page       |
| `/` → `Enter`          | Search               |
| `n` / `N`              | Next/prev match      |
| `Esc`                   | Clear search         |
| `d`                     | Toggle definition    |
| `w`                     | Open web dashboard   |
| `e`                     | Open web editor      |
| `q` / `Ctrl+C`         | Quit                 |
| `Shift` + mouse         | Select and copy text |

### Auto-Reconnection

The TUI automatically reconnects when the pipeline is updated, paused, resumed, or temporarily unavailable. It displays "Reconnecting..." and preserves previously received data. The TUI has a **30-minute timeout** — if the pipeline remains unreachable for 30 minutes, it closes automatically.

## Error Pattern Reference

> **Detailed error patterns and solutions are in the `data/` folder.**

| File                  | Contents                                           |
| --------------------- | -------------------------------------------------- |
| `error-patterns.json` | All known error patterns with causes and solutions |

**Data location:** `data/` (relative to this skill's directory)

### Log Analysis Script

Use the helper script to quickly analyze pipeline logs:

```bash
./scripts/analyze-logs.sh <pipeline-name>
./scripts/analyze-logs.sh <pipeline-name> --tail 100
```

The script checks for common error patterns and reports findings with recommendations.

---

## Common Issues Quick Reference

| Symptom            | Likely Cause           | Quick Fix                           |
| ------------------ | ---------------------- | ----------------------------------- |
| No data flowing    | `start_at: latest`     | Wait for new data or use `earliest` |
| Auth failed        | Wrong credentials      | Update secret with correct password |
| Connection refused | Network/firewall       | Check host, whitelist Goldsky IPs   |
| Storage exceeded   | Neon free tier (512MB) | Upgrade plan or clear data          |
| SQL error          | Bad transform syntax   | Validate YAML first                 |

## Troubleshooting

| Issue                    | Action                                                 |
| ------------------------ | ------------------------------------------------------ |
| Can't connect to inspect | Check pipeline is running with `goldsky turbo list`    |
| Logs are empty           | Pipeline may be new; wait for data or check `start_at` |
| TUI disconnects          | Auto-reconnects within 30 min; check pipeline status   |
| Can't find pipeline      | Verify correct project with `goldsky project list`     |

## Related Skills

- **`/goldsky-auth-setup`** - **Invoke this if user is not logged in**
- **`/goldsky-secrets`** - **Invoke this if credentials need to be updated**
- **`/turbo-pipelines`** - Deploy new pipelines or modify configuration
- **`/turbo-lifecycle`** - List or delete pipelines
