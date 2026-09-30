---
name: auth-setup
description: "Set up Goldsky CLI authentication and project configuration. Use this skill when the user needs to: install the goldsky CLI (what's the official install command?), run goldsky login (including when the browser opens but 'authentication failed'), run goldsky project list and see 'not logged in' or 'unauthorized', switch between Goldsky projects, check which project they're currently authenticated to, or fix 'unauthorized' errors when running goldsky turbo commands. Also use for 'walk me through setting up goldsky CLI from scratch for the first time', and when they just installed Goldsky and say 'Set it up and help me get started'. If any other Goldsky skill hits an auth error, redirect here first."
---

# Goldsky Authentication & Project Setup

Set up the Goldsky CLI, authenticate your account, and configure projects for your pipelines and subgraphs.

## Prerequisites

- [ ] macOS, Linux, or Windows with WSL (see Step 1 for binary compatibility)
- [ ] Internet connection
- [ ] Goldsky account (sign up at https://app.goldsky.com)

## Authentication Workflow

**Follow this workflow and verify each step. Execute commands and check results.**

### Step 1: Install and verify the CLI

Install missing tools yourself. Authentication remains a separate, manual step; do not ask the user to install binaries or enter a sudo password.

On macOS and Linux (including WSL), run the bundled [installer](scripts/install.sh) using its actual path in this skill folder:

```bash
bash /path/to/auth-setup/scripts/install.sh
```

The default installs Goldsky, Compose, and Turbo. Pass `cli` when only the base CLI is needed. For a Compose-only or Turbo-only task, pass `compose` or `turbo`; both include the base Goldsky CLI. The script uses user-writable directories, disables installation prompts even in a PTY, checks download failures and empty responses, and requires each requested binary to run successfully. It reuses working installations and repairs broken ones. No sudo or login is needed.

**Every new shell/tool call must restore PATH**, including authentication and project commands below. An export in a previous tool call does not persist:

```bash
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"
goldsky --version
goldsky compose --version
goldsky turbo --version
```

Check only the components requested. Do not trigger Turbo's interactive auto-installer when its binary is absent. Do not report setup complete if the installer or a required version check fails.

**Platform limits:** Goldsky and Compose publish macOS Intel/Apple Silicon and Linux x64/ARM64 binaries. The current Linux Turbo binary requires x64 and glibc 2.39+ (for example Ubuntu 24.04). A full install on Linux ARM64, older glibc, or musl must report incomplete; `compose` can still be installed separately. These are upstream binary limits, not reasons to ask for sudo or silently omit Turbo. The current Turbo Mac binary is Apple Silicon-only; Intel Macs can install Goldsky and Compose, but a full install must report incomplete.

**Windows:** the complete toolset currently runs inside WSL, not native PowerShell or Git Bash: Compose has no published Windows binary. Use an existing x64 Ubuntu 24.04+ WSL distribution for all three tools. See [Windows setup](references/windows.md) for PowerShell invocation and prerequisites. Keep installation, subsequent CLI commands, project files, and manual login in the same WSL environment. Installing/enabling WSL itself may require administrator access and a reboot; do not claim that prerequisite can always be automated without intervention.

Prerequisites inside the selected environment: Bash, curl, CA certificates, standard Unix utilities, internet access, and a writable home directory. If an environment lacks these, report the missing prerequisite instead of claiming installation succeeded.

### Step 2: Check Authentication Status

```bash
goldsky project list 2>&1
```

**Already logged in:** Output shows a table with project IDs and Names. Skip to Step 4.

**Not logged in:** Output contains `Make sure to run 'goldsky login'`. Continue to Step 3.

### Step 3: Have the User Log In

**Never handle the user's API token in the chat.** A token pasted into the conversation ends up in the transcript and is sent to the model — treat it like a password you must never see. Have the user authenticate themselves in their own terminal instead. The CLI persists credentials to disk, so the `goldsky` commands you run afterward will pick up their session automatically.

Tell the user to run this one command in their own terminal, then say when the browser tab says they are logged in:

```bash
goldsky login
```

The browser has to be on the same machine as that command. Do not ask for an API token, do not pass `--token`, and do not use a host-specific question tool. Then verify (Step 4). If verification shows they are still not logged in, ask them to run `goldsky login` again.

### Step 4: Verify Login

**ALWAYS verify after login:**

```bash
goldsky project list
```

**Success:** Exit code 0, shows table with projects

**Failure indicators:**

- `Make sure to run 'goldsky login'` still appears
- `invalid token` or `unauthorized`

If verification fails, ask the user to run `goldsky login` again.

## Completion Summary

After successful setup, provide a summary to the user:

```
## Setup Complete

**What was done:**
- ✓ Goldsky CLI installed (version X.X.X)
- Turbo: verified version, not requested, or explicit installation failure
- Compose: verified version, not requested, or explicit installation failure
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
| Installer asks for confirmation or sudo | Use the bundled installer, which creates a writable destination and passes `-f`. Do not retry with sudo |
| `turbo` or `compose` is missing or cannot run | Re-run the bundled installer for that component; check its exit status and platform requirements |
| Not logged in     | Ask the user to run `goldsky login` themselves in their terminal |
| Invalid token     | Ask user to generate a new token in dashboard          |
| Permission denied | User needs role upgrade from project Owner/Admin       |
| Session expired   | Ask the user to re-run `goldsky login` themselves      |

## Related

After authentication is complete, suggest next steps:

- **`/turbo-builder`** — Build and deploy a new pipeline interactively
- **`/datasets`** — Find the right dataset for your use case
- **`/secrets`** — Set up credentials for pipeline sinks (PostgreSQL, ClickHouse, Kafka, etc.)
