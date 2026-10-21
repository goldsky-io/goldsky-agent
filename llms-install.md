# Install the Goldsky docs MCP server in Cline

The Goldsky docs MCP server is a remote server. It needs no install, no API key, and no account.

1. Open the Cline MCP settings file (`cline_mcp_settings.json`). In the Cline panel, click **MCP Servers**, then **Configure MCP Servers**.
2. Add this entry under `mcpServers`:

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

3. Save the file. Cline connects and lists 3 tools:
   - `search_goldsky`: search the Goldsky docs.
   - `query_docs_filesystem_goldsky`: read full doc pages.
   - `submit_feedback`: report a problem with a docs page.
4. Test it. Ask Cline: "Using the goldsky-docs server, how do I get a wallet's token balances with Goldsky Feeds?"

The server reads public documentation only. To use the Goldsky products that the docs describe, you need a Goldsky account and API key from https://app.goldsky.com.
