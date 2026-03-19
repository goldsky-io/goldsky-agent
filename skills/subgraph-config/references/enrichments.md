# Enrichments Reference

Enrichments allow instant subgraphs to make `eth_call` requests within event handlers, enabling you to read on-chain state at the time an event is processed.

## When to Use Enrichments

- Reading token balances, allowances, or metadata at the time of a transfer
- Fetching contract state (e.g., pool reserves, token prices) when an event fires
- Enriching event data with additional on-chain context

## Configuration

Enrichments are configured per-instance in the instant subgraph JSON config:

```json
{
  "version": "1",
  "abis": {
    "ERC20": { "path": "./erc20-abi.json" }
  },
  "instances": [
    {
      "abi": "ERC20",
      "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "chain": "mainnet",
      "startBlock": 6082465,
      "enrichments": [
        {
          "name": "totalSupply",
          "source": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        },
        {
          "name": "balanceOf",
          "params": "event.params.to",
          "source": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        }
      ]
    }
  ]
}
```

## Enrichment Call Fields

| Field | Required | Type | Description |
| ----- | -------- | ---- | ----------- |
| `name` | Yes | string | The exact name of the eth call as defined in the ABI. The runtime calls `try_<name>` to safely handle reverts. |
| `abi` | No | string | Name of the ABI defining the call (defaults to the instance ABI) |
| `source` | No | string | Contract address expression for the call (defaults to the instance address) |
| `params` | No | string | Parameter expression for the eth call. Omit if the call takes no parameters. Multiple params separated by commas, e.g., `"event.params.owner, event.params.tokenId"` |
| `depends_on` | No | array of string | List of call reference names this call depends on. Use when a parameter is derived from a previously defined call. |
| `required` | No | boolean | If true, the call must succeed or the enrichment is aborted and the subgraph enters error state |
| `declared` | No | boolean | If true, the call is executed and cached before the mapping handler runs (performance optimization — can reduce indexing time up to 10x) |
| `conditions` | No | object | Optional pre/post condition expressions to test before/after the call |
| `conditions.pre` | No | string | Condition to test before performing the call |
| `conditions.post` | No | string | Condition to test after performing the call |

## Enrichment Expressions

Expressions are AssemblyScript expressions that produce values from the runtime context:

- **`event`** / **`call`** — The incoming event/call object with parameters converted to entity fields
- **`entity`** — The parent entity object (already saved before enrichment begins)
- **`calls`** — Object containing results of previously executed eth calls

Expressions support string concatenation, type transformations, math, and logical branching.

## Advanced Example: Chained Calls with Dependencies

```json
"enrichments": [
  {
    "name": "token0",
    "required": true
  },
  {
    "name": "token1",
    "required": true
  },
  {
    "name": "symbol",
    "abi": "ERC20",
    "source": "calls.token0",
    "depends_on": ["token0"]
  },
  {
    "name": "decimals",
    "abi": "ERC20",
    "source": "calls.token0",
    "depends_on": ["token0"],
    "declared": true
  }
]
```

## Notes

- Enrichments increase indexing time as they require RPC calls for each event
- The called function must be a `view` or `pure` function (read-only)
- Use `declared: true` for frequently called functions to pre-execute and cache results (up to 10x faster indexing)
- Always use `try_` prefix when calling contract methods in handlers to safely handle reverts
- Results are available in the generated mapping code via the `calls` object
- For complex enrichment logic, consider using source code subgraphs with custom handlers instead
- If `required: true` and the call fails, the enrichment is aborted — no entity mapping takes place
