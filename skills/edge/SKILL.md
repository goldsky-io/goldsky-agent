Goldsky Edge is a managed, high-performance RPC endpoint service for EVM blockchains, built on eRPC — an open-source fault-tolerant EVM RPC proxy. It provides globally-distributed, low-latency RPC access with intelligent routing, caching, failover, and built-in observability.

# Goldsky Edge (RPC Endpoints)

## What Edge Does

Edge sits between your application and blockchain RPC providers. It adds:

- **Performance**: Global edge infrastructure across 8+ regions, sub-100ms latency, tip-of-chain CDN caching
- **Resiliency**: Automatic failover across multiple providers for 99.9% uptime, hedged parallel requests
- **Data Integrity**: Cross-validates responses from multiple nodes, tracks block heights, enforces consensus checks
- **Cost Control**: Request deduplication, intelligent routing, configurable rate limiting
- **Indexing Optimizations**: Auto-splits large `eth_getLogs` requests, routes historical queries to archive nodes

## Quickstart

### Endpoint Format

```
https://edge.goldsky.com/standard/evm/{chainId}?secret=YOUR_SECRET
```

Replace `{chainId}` with the chain ID (e.g., `1` for Ethereum, `8453` for Base, `42161` for Arbitrum).

### Authentication

Three options:
- **Query parameter**: `?secret=YOUR_SECRET`
- **Header**: `X-ERPC-Secret-Token: YOUR_SECRET`
- **x402 (pay-per-request)**: Clients without a secret receive an HTTP 402 response with payment requirements. An x402-compatible client signs a USDC payment and retries; Edge settles via a facilitator before forwarding the request upstream. Payment is settled on **Base** in USDC (currently Base Sepolia, chain `84532`). Pricing is `$0.000005` per request (same as the standard `$5 per million` rate). See https://www.x402.org/ for the protocol spec.

### Example (curl)

```bash
curl -s "https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Example (viem)

```typescript
import { createPublicClient, http } from "viem";
import { mainnet } from "viem/chains";

const client = createPublicClient({
  chain: mainnet,
  transport: http("https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET"),
});
```

### Example (ethers.js)

```typescript
import { JsonRpcProvider } from "ethers";

const provider = new JsonRpcProvider(
  "https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET"
);
```

## Managing Edge Endpoints in the Webapp

Edge endpoints are created and managed in the Goldsky webapp at `/dashboard/rpc-edge`.

### Creating an Endpoint

1. Navigate to the Edge RPC page (`/dashboard/rpc-edge`)
2. Click "Create endpoint"
3. Enter a name (lowercase letters, numbers, hyphens; must start with a letter; 3-50 chars)
4. Optionally select a rate limit budget
5. An API key is generated automatically (format: `gs_edge_...`)

### Endpoint Management

- **View metrics**: See request counts, error rates, and response times on the endpoint detail page
- **View logs**: Searchable, filterable logs for debugging
- **Reveal API key**: View your secret key (click to copy)
- **Rate limiting**: Update the rate limit budget for an endpoint
- **Pause/Resume**: Toggle an endpoint on or off
- **Delete**: Remove an endpoint permanently

### Plan Limits

- **Free (Starter)**: 1 endpoint, subject to free-tier request limits
- **Scale**: Multiple endpoints, pay-as-you-go
- **Enterprise**: Unlimited endpoints

## Rate Limiting

Rate limits are configured per secret in the Goldsky Dashboard. Pick one of the following named tiers (source: https://docs.goldsky.com/edge-rpc/platform/security#rate-limiting):

| Budget ID | Total RPS | Per-IP RPS | Use case |
|-----------|-----------|------------|----------|
| `None (Unlimited)` | Unlimited | Unlimited | No rate limiting |
| `edge-tier-6krpm-total-unlimited-per-ip` | ~100 | Unlimited | Low volume |
| `edge-tier-60krpm-total-unlimited-per-ip` | ~1,000 | Unlimited | Medium volume |
| `edge-tier-180krpm-total-unlimited-per-ip` | ~3,000 | Unlimited | High volume |
| `edge-tier-360krpm-total-unlimited-per-ip` | ~6,000 | Unlimited | Very high volume |
| `edge-tier-600krpm-total-unlimited-per-ip` | ~10,000 | Unlimited | Enterprise volume |
| `edge-tier-6krpm-total-500rpm-per-ip` | ~100 | ~8 | Low volume + per-IP protection |
| `edge-tier-60krpm-total-500rpm-per-ip` | ~1,000 | ~8 | Medium volume + per-IP protection |
| `edge-tier-180krpm-total-500rpm-per-ip` | ~3,000 | ~8 | High volume + per-IP protection |
| `edge-tier-360krpm-total-500rpm-per-ip` | ~6,000 | ~8 | Very high volume + per-IP protection |
| `edge-tier-600krpm-total-500rpm-per-ip` | ~10,000 | ~8 | Enterprise volume + per-IP protection |
| `edge-tier-unlimited-total-100rpm-per-ip` | Unlimited | ~1.7 | Strict per-IP only |
| `edge-tier-unlimited-total-500rpm-per-ip` | Unlimited | ~8 | Moderate per-IP only |

- **Total RPS** = max requests/sec across all IPs using this secret
- **Per-IP RPS** = max requests/sec from a single client IP

Rate limit budgets internally define rules with:
- **method** — which RPC method(s) the limit applies to (supports wildcards)
- **maxCount** — maximum number of requests
- **period** — time window (e.g. per second, per minute)

## Supported Networks

**Live registry** (authoritative — always check this before recommending a chain): `GET https://edge.goldsky.com/`

Returns JSON with a `standard` array of every network Edge serves. Each entry has:
- `id` — e.g. `evm:1` (prefix + chain ID)
- `alias` — human name (e.g. `mainnet`, `base`, `polygon`)
- `blockTimeMs` — average block time
- `state` — `OK` when operational

```bash
# List all supported chain IDs
curl -s https://edge.goldsky.com/ | jq '.standard[].id'

# Find a specific chain
curl -s https://edge.goldsky.com/ | jq '.standard[] | select(.id=="evm:8453")'
```

Highlights include Ethereum, Arbitrum One, Base, Optimism, Polygon zkEVM, BSC, Avalanche, Berachain, HyperEVM, Monad, Sei, Sonic, Unichain, zkSync, plus their testnets — but the registry above is the source of truth and includes many more.

For the human-readable docs page: https://docs.goldsky.com/chains/supported-networks

## Special Capabilities

### Flashblocks

Faster block confirmations on OP Stack chains (Base, Optimism, Unichain and their testnets). Enable by adding:
- Query parameter: `use-upstream=flashblocks*`
- Or header: `X-ERPC-Use-Upstream: flashblocks*`

### HyperEVM System Transactions

Two distinct node pools for HyperEVM:
- `use-upstream=systx*` — Archive nodes with system transactions (for indexing)
- `use-upstream=standard*` — Realtime nodes without system transactions (for frontend dApps)

## Pricing

- **$5 per million requests** — all RPC methods priced equally (no surcharges for `eth_getLogs` or trace methods)
- **Up to 500M requests/month** at $5/million
- **500M+**: Volume discounts available (contact sales)

## Monitoring

Each endpoint has a built-in Grafana dashboard showing:
- Total RPC requests and requests per second
- Network and method usage breakdowns
- Response time percentiles (P50/P90/P99)
- Error rates and detailed error logs
- Rate-limited request tracking
- Multiplexed and hedged request metrics

## Error Codes

Edge normalizes errors from upstream providers:

| Code | Meaning |
|------|---------|
| -32005 | Rate limit exceeded |
| -32012 | Range too large (eth_getLogs) |
| -32014 | Missing data |
| -32015 | Node timeout |
| -32016 | Unauthorized |

Plus standard JSON-RPC errors (-32700, -32600, -32601, -32602, -32603) and EVM-specific errors (-32000, -32003, 3).

## Supported RPC Methods

Full coverage of standard EVM JSON-RPC methods across five namespaces (60+ methods). Each method has its own docs page at `https://docs.goldsky.com/edge-rpc/evm/methods/{method_name}` — use it to confirm params, return shape, and any Edge-specific behavior before constructing a call.

**Method index**: https://docs.goldsky.com/edge-rpc/evm/methods

### `eth_*` — core chain queries and transactions
`eth_accounts`, `eth_blobBaseFee`, `eth_blockNumber`, `eth_call`, `eth_chainId`, `eth_createAccessList`, `eth_estimateGas`, `eth_feeHistory`, `eth_gasPrice`, `eth_getBalance`, `eth_getBlockByHash`, `eth_getBlockByNumber`, `eth_getBlockReceipts`, `eth_getBlockTransactionCountByHash`, `eth_getBlockTransactionCountByNumber`, `eth_getCode`, `eth_getFilterChanges`, `eth_getFilterLogs`, `eth_getLogs`, `eth_getProof`, `eth_getStorageAt`, `eth_getTransactionByBlockHashAndIndex`, `eth_getTransactionByBlockNumberAndIndex`, `eth_getTransactionByHash`, `eth_getTransactionCount`, `eth_getTransactionReceipt`, `eth_getUncleByBlockHashAndIndex`, `eth_getUncleByBlockNumberAndIndex`, `eth_getUncleCountByBlockHash`, `eth_getUncleCountByBlockNumber`, `eth_maxPriorityFeePerGas`, `eth_newBlockFilter`, `eth_newFilter`, `eth_newPendingTransactionFilter`, `eth_pendingTransactions`, `eth_sendRawTransaction`, `eth_subscribe`, `eth_syncing`, `eth_uninstallFilter`, `eth_unsubscribe`

### `debug_*` — raw block/receipt data and EVM tracing
`debug_getRawBlock`, `debug_getRawHeader`, `debug_getRawReceipts`, `debug_getRawTransaction`, `debug_traceBlockByHash`, `debug_traceBlockByNumber`, `debug_traceCall`, `debug_traceTransaction`

### `trace_*` — OpenEthereum-style tracing
`trace_block`, `trace_call`, `trace_callMany`, `trace_filter`, `trace_get`, `trace_rawTransaction`, `trace_replayBlockTransactions`, `trace_replayTransaction`, `trace_transaction`

### `net_*` — network metadata
`net_listening`, `net_peerCount`, `net_version`

### `web3_*` — client metadata
`web3_clientVersion`, `web3_sha3`

### Request shape

All methods use the standard JSON-RPC 2.0 envelope. Example for `eth_getLogs`:

```bash
curl -s "https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "eth_getLogs",
    "params": [{
      "fromBlock": "0x1000000",
      "toBlock": "0x1000064",
      "address": "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    }]
  }'
```

Before using trace methods (`debug_trace*`, `trace_*`), check the per-method page — not every chain supports every tracer, and some methods have chain-specific quirks documented there.

---

# eRPC (Open-Source)

Edge is built on **eRPC**, an open-source fault-tolerant EVM RPC proxy. For capabilities beyond what Goldsky Edge exposes (self-hosting, custom cache drivers, custom selection policies, multi-provider failover, etc.), users may want to run eRPC directly.

For full eRPC reference (features, config, APIs), fetch the LLM-optimized docs bundle: **https://docs.erpc.cloud/llms.txt**

## Goldsky Documentation Links

- Edge Introduction: https://docs.goldsky.com/edge-rpc/introduction
- Edge Quickstart: https://docs.goldsky.com/edge-rpc/quickstart
- Why Edge: https://docs.goldsky.com/edge-rpc/why-edge
- Security & Rate Limiting: https://docs.goldsky.com/edge-rpc/platform/security
- Monitoring: https://docs.goldsky.com/edge-rpc/platform/monitoring
- Flashblocks: https://docs.goldsky.com/edge-rpc/capabilities/flashblocks
- HyperEVM System Tx: https://docs.goldsky.com/edge-rpc/capabilities/hyperevm-system-transactions
- Error Codes: https://docs.goldsky.com/edge-rpc/evm/error-codes
- RPC Methods Index: https://docs.goldsky.com/edge-rpc/evm/methods
- Pricing: https://docs.goldsky.com/pricing/summary
- Supported Networks: https://docs.goldsky.com/chains/supported-networks
