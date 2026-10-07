---
name: auth-setup
description: "Set up Goldsky CLI authentication and project configuration. Use this skill when the user needs to: install the goldsky CLI (what's the official install command?), run goldsky login (including when the browser opens but 'authentication failed'), run goldsky project list and see 'not logged in' or 'unauthorized', switch between Goldsky projects, check which project they're currently authenticated to, or fix 'unauthorized' errors when running goldsky turbo commands. Also use for 'walk me through setting up goldsky CLI from scratch for the first time', and when they just installed Goldsky and say 'Set it up and help me get started'. If any other Goldsky skill hits an auth error, redirect here first."
---

# Goldsky Authentication & Project Setup

Set up the Goldsky CLI, authenticate your account, and configure projects for your pipelines and subgraphs.

## Prerequisites

- [ ] macOS, Linux, or Windows with WSL (see Step 1 for binary compatibility)
- [ ] Internet connection
- [ ] A Goldsky account. Creating one happens in the browser during Step 3. Do not send the user to sign up as a separate step.

## Authentication Workflow

**Follow this workflow and verify each step. Execute commands and check results.**

### Step 1: Install and verify the CLI

Install missing tools yourself. Do not ask the user to install binaries or enter a sudo password. You run login in Step 3. The user only approves it in the browser.

On macOS and Linux (including WSL), run the bundled [installer](scripts/install.sh) from this skill's directory. Resolve that path yourself. Do not ask the user where it is.

```bash
bash scripts/install.sh
```

The default installs Goldsky, Compose, and Turbo. Pass `cli` when only the base CLI is needed. For a Compose-only or Turbo-only task, pass `compose` or `turbo`; both include the base Goldsky CLI. The script installs `@goldskycom/cli@13.17.0` with `npm install --global --prefix "$HOME/.local"` (no sudo, no `@latest`), then runs `goldsky compose install` and `goldsky turbo install` for the requested extensions. If `goldsky turbo install` is not a command, it exits 1. It does not download or execute a remote shell script. Missing npm is a failure. It requires each requested command's version check to succeed. No login is needed.

**Every new shell/tool call must restore PATH**, including authentication and project commands below. An export in a previous tool call does not persist:

```bash
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"
goldsky --version
goldsky compose --version
goldsky turbo --version
```

Check only the components requested. Do not trigger Turbo's interactive auto-installer when its binary is absent. Do not report setup complete if the installer or a required version check fails.

**Platform limits:** `goldsky turbo install` enforces the published Turbo binary limits. Do not curl a fallback and do not ask for sudo if it fails. The current Linux Turbo binary requires x64 and glibc 2.39+ (for example Ubuntu 24.04). The current Turbo Mac binary is Apple Silicon-only. Goldsky and Compose publish macOS Intel/Apple Silicon and Linux x64/ARM64 binaries, so `compose` can still be installed when Turbo cannot. Report the CLI's error. A Turbo failure is not a successful full install.

**Windows:** the complete toolset currently runs inside WSL, not native PowerShell or Git Bash: Compose has no published Windows binary. Use an existing x64 Ubuntu 24.04+ WSL distribution for all three tools. See [Windows setup](references/windows.md) for PowerShell invocation and prerequisites. Keep installation, subsequent CLI commands, project files, and `goldsky login` in the same WSL environment. Run login yourself there. Installing/enabling WSL itself may require administrator access and a reboot; do not claim that prerequisite can always be automated without intervention.

Prerequisites inside the selected environment: Bash, npm, CA certificates, standard Unix utilities, internet access, and a writable home directory. If an environment lacks these, report the missing prerequisite instead of claiming installation succeeded. Do not install curl in order to pipe a remote installer.

### Step 2: Check Authentication Status

```bash
goldsky project list 2>&1
```

**Already logged in:** Output shows a table with project IDs and Names. Skip to Step 4.

**Not logged in:** Output contains `Make sure to run 'goldsky login'`. Continue to Step 3.

### Step 3: Log in

**Never handle the user's API token in the chat.** A token pasted into the conversation ends up in the transcript and is sent to the model. Do not ask for one, and do not pass `--token`.

Run `goldsky login` yourself, with PATH restored, and leave it running for up to 5 minutes. It prints a URL, opens the browser, and writes the token to disk. The token is not printed. The user only approves the login in that browser, on this same machine. Creating an account or choosing a project happens there too. If the browser does not open, open the printed URL yourself. Give the user that URL only when you cannot open a browser.

If this host kills the command before login finishes, run it again. Hand the user the command only when you have no shell. Then verify (Step 4).

### Step 4: Verify Login

**ALWAYS verify after login:**

```bash
goldsky project list
```

**Success:** Exit code 0, shows table with projects

**Failure indicators:**

- `Make sure to run 'goldsky login'` still appears
- `invalid token` or `unauthorized`

If verification fails, run `goldsky login` again.

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

If they have not said what they are trying to do, ask, and suggest only jobs the installed skills can do. Do not create a secret, pipeline, subgraph, or deployment until they pick one and agree.

## Command Reference

| Command                        | Purpose                         | Key Flags               |
| ------------------------------ | ------------------------------- | ----------------------- |
| `goldsky login`                | Authenticate with Goldsky       | Opens the browser. Do not pass `--token` |
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
| Installer asks for confirmation or sudo | Use the bundled installer. It installs into `$HOME/.local` with npm and does not use sudo. Do not retry with sudo or a remote shell script |
| `turbo` or `compose` is missing or cannot run | Re-run the bundled installer for that component. If `goldsky turbo install` is not a command, stop. Do not curl an installer |
| Not logged in     | Run `goldsky login` yourself and leave it running until the browser login finishes |
| Invalid token     | Run `goldsky login` again. Do not ask for a token      |
| Permission denied | User needs role upgrade from project Owner/Admin       |
| Session expired   | Run `goldsky login` again                                  |

## Related

After authentication is complete, suggest next steps:

- **`/turbo-builder`** — Build and deploy a new pipeline interactively
- **`/datasets`** — Find the right dataset for your use case
- **`/secrets`** — Set up credentials for pipeline sinks (PostgreSQL, ClickHouse, Kafka, etc.)
