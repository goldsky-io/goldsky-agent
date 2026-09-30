---
name: get-started
description: Install Goldsky skills, the docs MCP, and the CLIs, log in, then ask what the user wants to do
---

Set up Goldsky. Do every step yourself. Skip a step that is already done. The user only approves login in the browser, then tells you what they are trying to do. Do not ask them to run commands, edit config files, paste a token, choose an installer, or pick an agent.

1. Skills. If you cannot already read a Goldsky `auth-setup` skill, install the skills for this host without a confirmation prompt:

```bash
npx skills add goldsky-io/goldsky-agent -y -g -a <agent>
```

Use `claude-code`, `cursor`, `codex`, or `opencode` for `<agent>`. If you cannot tell which host you are, use `-a '*'`.

2. Docs MCP. If `https://docs.goldsky.com/mcp` is not already connected, add it yourself. On Claude Code run:

```bash
claude mcp add --transport http goldsky-docs https://docs.goldsky.com/mcp
```

On Cursor, merge this into `.cursor/mcp.json` without removing other servers:

```json
{
  "mcpServers": {
    "goldsky-docs": {
      "type": "http",
      "url": "https://docs.goldsky.com/mcp"
    }
  }
}
```

On any other host, look up that host's MCP config and write an HTTP server named `goldsky-docs` at that URL. A plugin install that already registered this server counts as done.

3. CLIs. Resolve `scripts/install.sh` from the `auth-setup` skill you just installed, or from this plugin, and run it with bash. Do not ask where it is, do not run `curl` installers, and do not ask for sudo. It installs the Goldsky CLI, Compose, and Turbo into user-writable directories. On Windows, resolve `scripts/install.ps1` the same way and follow the Windows section of `auth-setup`: run install, login, and later commands yourself inside the same WSL distribution. Enabling WSL is the one step you cannot do — say so only when no distribution is installed. On every later command, restore PATH:

```bash
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"
```

If Turbo or Compose cannot be installed on this platform, say which component failed and continue with the ones that run.

4. Login. Run `goldsky project list`. A project table means they are already logged in. Otherwise run `goldsky login` yourself and leave it running for up to 5 minutes. It prints a URL, opens the browser, and writes the token to disk. The token is not printed. Do not ask for an API token and do not pass `--token`. The user only approves the login in that browser, on this same machine. Creating an account or choosing a project happens there too. If the browser does not open, open the printed URL yourself. Give the user that URL only when you cannot open a browser. If the command is killed before it finishes, run it again. Hand the user the command only when you have no shell.

5. Run `goldsky project list` again. Report the CLI version and the active project.

6. Ask what they are trying to accomplish. Suggest only jobs the installed skills can do, for example:

- Stream an event from a chain into their database, such as USDC transfers on Base
- Check whether Goldsky already has a dataset they need
- Build a subgraph for a contract
- Get a managed RPC endpoint

Mention a Compose app only if the compose skill is installed. Do not create a secret, pipeline, subgraph, or deployment until they pick one and agree.
