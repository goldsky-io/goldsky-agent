# Install the Goldsky docs MCP server in Cline

The Goldsky docs MCP server is a remote server. It needs no install, no API key, and no account. Do not install packages, clone repositories, or read Cline's own source code. Edit one JSON file.

1. Open the Cline MCP settings file `cline_mcp_settings.json`. Use the first path that exists:
   - Cline 4 and later (all platforms): `~/.cline/data/settings/cline_mcp_settings.json`
   - Earlier Cline on macOS: `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
   - Earlier Cline on Linux: `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
   - Earlier Cline on Windows: `%APPDATA%\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json`

   In Cursor, VSCodium, or Windsurf, replace `Code` with that editor's folder name. If no file exists, create the first path with `{"mcpServers": {}}`.
2. Add this entry under `mcpServers`. Keep any servers that are already there.

```json
{
  "mcpServers": {
    "goldsky-docs": {
      "type": "streamableHttp",
      "url": "https://docs.goldsky.com/mcp",
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

3. Save the file. Cline reloads it, connects, and lists 3 tools:
   - `search_goldsky`: search the Goldsky docs.
   - `query_docs_filesystem_goldsky`: read full doc pages.
   - `submit_feedback`: report a problem with a docs page.
4. Test it. Ask Cline: "Using the goldsky-docs server, how do I get a wallet's token balances with Goldsky Feeds?"

The server reads public documentation only. To use the Goldsky products that the docs describe, you need a Goldsky account and API key from https://app.goldsky.com.
