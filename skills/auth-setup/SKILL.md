---
name: auth-setup
description: "Set up Goldsky CLI authentication and project configuration. Use this skill when the user needs to: install the goldsky CLI (what's the official install command?), run goldsky login (including when the browser opens but 'authentication failed'), run goldsky project list and see 'not logged in' or 'unauthorized', switch between Goldsky projects, check which project they're currently authenticated to, or fix 'unauthorized' errors when running goldsky turbo commands. Also use for 'walk me through setting up goldsky CLI from scratch for the first time'. If any other Goldsky skill hits an auth error, redirect here first."
---

# Goldsky Authentication & Project Setup

Set up the Goldsky CLI, authenticate your account, and configure projects for your pipelines and subgraphs.

## Prerequisites

- [ ] macOS, Linux, or WSL (Windows Subsystem for Linux)
- [ ] Internet connection
- [ ] Goldsky account (sign up at https://app.goldsky.com)

## Authentication Workflow

**Follow this workflow and verify each step. Execute commands and check results.**

### Step 1: Check CLI Installation

```bash
which goldsky && goldsky --version
```

**Success:** Path and version displayed (e.g., `/usr/local/bin/goldsky` and `13.2.0`)

**Not installed:** Tell the user to run this in their terminal:

```bash
curl https://goldsky.com | sh
```

This requires sudo password entry. Use AskUserQuestion to confirm installation:

```
Question: "Please run this command in your terminal to install the Goldsky CLI:"
Code block: curl https://goldsky.com | sh

Options:
1. Label: "Done, it's installed"
   Description: "I ran the command and the CLI is now installed"

2. Label: "I need help"
   Description: "I encountered an error during installation"
```

After confirmation, verify with `which goldsky && goldsky --version`.

### Step 2: Check Authentication Status

```bash
goldsky project list 2>&1
```

**Already logged in:** Output shows a table with project IDs and Names. Skip to Step 4.

**Not logged in:** Output contains `Make sure to run 'goldsky login'`. Continue to Step 3.

### Step 3: Have the User Log In

**Never handle the user's API token in the chat.** A token pasted into the conversation ends up in the transcript and is sent to the model — treat it like a password you must never see. Have the user authenticate themselves in their own terminal instead. The CLI persists credentials to disk, so the `goldsky` commands you run afterward will pick up their session automatically.

Ask the user to run login themselves:

```bash
goldsky login                       # opens a browser to authenticate (simplest)
# or, if they prefer a token or have no browser available:
goldsky login --token <YOUR_TOKEN>  # they type this themselves — do not ask them to paste the token to you
```

Need a token? Go to https://app.goldsky.com → Settings → API Tokens → Create Token (it won't be shown again).

Use AskUserQuestion to confirm — do NOT collect the token yourself:

```
Question: "Run `goldsky login` in your terminal to authenticate, then let me know:"

Options:
1. Label: "Done, I'm logged in"
   Description: "I ran login and it succeeded"

2. Label: "I need help"
   Description: "I hit an error during login"
```

Then verify (Step 4). If verification shows you're still not logged in, ask the user to re-run login — never ask them to hand you the token.

### Step 4: Verify Login

**ALWAYS verify after login:**

```bash
goldsky project list
```

**Success:** Exit code 0, shows table with projects

**Failure indicators:**

- `Make sure to run 'goldsky login'` still appears
- `invalid token` or `unauthorized`

If verification fails, ask user to generate a new token and repeat Step 3.

## Completion Summary

After successful setup, provide a summary to the user:

```
## Setup Complete

**What was done:**
- ✓ Goldsky CLI installed (version X.X.X)
- ✓ Authenticated to Goldsky
- ✓ Connected to project: [project-name]

**Your available projects:**
[List projects from goldsky project list output]

**Next steps - try these skills:**
- `/secrets` - Set up credentials for pipeline sinks (PostgreSQL, ClickHouse, Kafka)
- Ask "create a pipeline" to start building data pipelines
- Ask "deploy a subgraph" to deploy a subgraph to Goldsky
```

## Command Reference

| Command                        | Purpose                         | Key Flags               |
| ------------------------------ | ------------------------------- | ----------------------- |
| `goldsky login`                | Authenticate with Goldsky       | `--token` for API token |
| `goldsky logout`               | Remove local credentials        |                         |
| `goldsky project list`         | List all projects you belong to |                         |
| `goldsky project create`       | Create a new project            | `--name` (required)     |
| `goldsky project users list`   | List users in current project   |                         |
| `goldsky project users invite` | Invite user to project          | `--emails`, `--role`    |

## Common Patterns

### Create a New Project

```bash
goldsky project create --name "my-new-project"
```

### Invite Team Members

```bash
goldsky project users invite --emails user@example.com --role Editor
```

**Available roles:** `Owner`, `Admin`, `Editor`, `Viewer`

### Switching accounts

```bash
goldsky logout
goldsky login
# MUST verify after: goldsky project list
```

## Error Patterns

| Pattern                             | Meaning                       |
| ----------------------------------- | ----------------------------- |
| `Make sure to run 'goldsky login'`  | Not authenticated             |
| `invalid token` / `unauthorized`    | Token is incorrect or expired |
| `Permission denied` / `403`         | User lacks required role      |
| `token expired` / `session expired` | Need to re-authenticate       |

## Troubleshooting

| Issue             | Action                                                 |
| ----------------- | ------------------------------------------------------ |
| Not logged in     | Ask the user to run `goldsky login` themselves in their terminal |
| Invalid token     | Ask user to generate a new token in dashboard          |
| Permission denied | User needs role upgrade from project Owner/Admin       |
| Session expired   | Ask the user to re-run `goldsky login` themselves      |

## Related

After authentication is complete, suggest next steps:

- **`/turbo-builder`** — Build and deploy a new pipeline interactively
- **`/datasets`** — Find the right dataset for your use case
- **`/secrets`** — Set up credentials for pipeline sinks (PostgreSQL, ClickHouse, Kafka, etc.)
