# Privacy Policy — Goldsky Agent plugin

_Last updated: 2026-09-28_

This notice describes the data flows of the **Goldsky Agent plugin** in this
repository. Use of Goldsky services is covered by the
[Goldsky Privacy Policy](https://goldsky.com/privacy).

## Plugin components

The plugin contains Markdown skills, an agent definition, shell hooks, and
configuration for the remote Goldsky documentation MCP server. The bundled
hooks contain no analytics or crash-reporting instrumentation. Installing the
plugin does not eliminate the network requests made by its configured MCP
server, the Goldsky CLI, or your agent host.

## Data flows

| Component | Behavior |
| --- | --- |
| Documentation MCP | The host connects to `https://docs.goldsky.com/mcp` and sends documentation queries. This is a remote, unauthenticated service for public documentation. Requests disclose the query and connection metadata such as IP address to the service. Do not include credentials or confidential project data in documentation queries. |
| Skill instructions | Your agent may read and write local project files and run the Goldsky CLI or other tools as described by a skill. CLI operations can send pipeline configuration, project identifiers, uploaded files, or secret values to Goldsky services, depending on the command. RPC and Compose workflows may also contact configured third-party providers or blockchain networks. |
| Pre-deploy hooks | Hooks read the shell command and working directory supplied by the host, inspect a local pipeline YAML file, and may invoke `goldsky turbo validate` and `goldsky secret list`. The secret-list command makes an authenticated Goldsky API request and returns secret metadata. The scripts do not directly read the CLI credential file or fetch secret values. They do not explicitly write files, though the CLI has its own behavior. |
| Post-deploy hook | The hook reads the command output supplied by the host and may emit an inspection reminder. It does not run `goldsky turbo inspect` itself. |
| Hook messages and tool output | Validation decisions can expose a file path or missing secret names to the host. CLI output and files read by your agent can become part of the host's conversation or logs. Treat secret names and project configuration as potentially visible to your agent provider. |

## Credentials and control

Authentication is handled by the Goldsky CLI. Commands invoked by the agent or
hooks use the CLI's authenticated session; authenticated requests send
credentials to the relevant service. The bundled hooks do not themselves
print authentication tokens.

The authentication skill tells agents not to request API tokens in chat. Use
the CLI's login flow and review commands that create secrets or change
resources. Your host's permissions and plugin settings control tool execution;
disable the plugin or its hooks/MCP configuration there to stop those integrations.

## Service and host policies

Goldsky service collection, use, sharing, and privacy choices are described in
[Goldsky's Privacy Policy](https://goldsky.com/privacy). The plugin does not
set separate service retention periods or model-training policies.

Your agent host, model provider, marketplace, and any third-party services you
configure have their own policies and settings for conversations, tool output,
logs, retention, and training. This notice does not override those policies.

## Contact

Questions or a privacy concern: <support@goldsky.com>. Security issues: see
[SECURITY.md](./SECURITY.md).
