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

Two options:
- **Query parameter**: `?secret=YOUR_SECRET`
- **Header**: `X-ERPC-Secret-Token: YOUR_SECRET`

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

Configurable per endpoint. Options range from ~100 RPS to ~10,000 RPS total, with optional per-IP limits. An "unlimited" option is available on higher tiers.

Rate limit budgets define rules with:
- **method**: Which RPC method(s) the limit applies to (supports wildcards)
- **maxCount**: Maximum number of requests
- **period**: Time window (e.g., per second, per minute)

## Supported Networks (35+)

**Mainnets**: Abstract, Arbitrum One, Avalanche, Base, Berachain, Blast, BSC, Cyber, Flare, Gnosis, Gravity, HyperEVM, Kaia, Kava, Linea, Monad, Optimism, Polygon zkEVM, Scroll, Sei, Sonic, Swell, Unichain, Zircuit, zkSync, Zora

**Testnets**: Arbitrum Sepolia, Base Sepolia, HyperEVM Testnet, Monad Testnet, Optimism Sepolia, Somnia Testnet, Unichain Testnet

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

Full coverage of standard EVM JSON-RPC methods including `eth_*`, `debug_*`, `trace_*`, `net_*`, and `web3_*` namespaces (60+ methods).

---

# eRPC (Open-Source)

Edge is built on **eRPC**, an open-source fault-tolerant EVM RPC proxy. Users who need capabilities beyond what Goldsky Edge exposes may want to run eRPC directly.

**GitHub**: https://github.com/erpc/erpc
**Docs**: https://docs.erpc.cloud/

## eRPC Core Features (Beyond Edge)

These are capabilities available in standalone eRPC that power users may find valuable:

### Caching (Re-org Aware)

- Four cache drivers: Memory, Redis, PostgreSQL, DynamoDB
- Finality-aware with states: finalized, unfinalized, realtime, unknown
- Per-method cache policies with TTL and finality matching
- Block re-org protection via reference tracking
- Built-in zstd compression (50-90% storage savings)

### Failover & Resilience

- **Retry**: Configurable max attempts, delay, backoff, jitter
- **Circuit breaker**: Opens after configurable failure thresholds
- **Timeout**: Per-method configurable durations
- **Hedge**: Parallel requests to backup upstreams after delay
- **Consensus**: Multi-upstream agreement with configurable penalties

### Load Balancing

- Score-based routing using real-time metrics (error rate, latency, throttling, block lag)
- Configurable score multipliers and hysteresis
- Custom TypeScript evaluation functions for selection policies

### Multi-Chain Support

- 2,000+ chains and 4,000+ public RPC endpoints out of the box
- 20+ native provider integrations (Alchemy, Infura, dRPC, BlastAPI, QuickNode, Ankr, etc.)
- Automatic chain detection from provider API keys

### Authentication Options

- Secret (API key), Network (IP allowlist), JWT, SIWE (Sign-in with Ethereum), x402 (pay-per-request)
- Per-strategy method filtering and rate limit budgets

### Data Integrity

- Block height enforcement across upstreams
- getLogs range validation and auto-splitting
- Response validation: bloom filter checks, log index validation, hash uniqueness
- Misbehavior logging to file or S3

### Configuration

eRPC uses `erpc.yaml` or `erpc.ts` config files organized by:
- **Projects**: Top-level container with auth, CORS, rate limits, networks, upstreams
- **Networks**: Blockchain chains (e.g., `evm:42161` for Arbitrum)
- **Upstreams**: Individual RPC endpoints with failsafe policies
- **Providers**: Higher-level abstraction — one API key auto-generates upstreams for all chains
- **Rate limit budgets**: Named, reusable configs with method/count/period rules

### Running eRPC Independently

```bash
# Quick start with npx
npx start-erpc

# Or via Docker
docker run -v $(pwd)/erpc.yaml:/root/erpc.yaml ghcr.io/erpc/erpc
```

## Documentation Links

- Edge Introduction: https://docs.goldsky.com/edge-rpc/introduction
- Edge Quickstart: https://docs.goldsky.com/edge-rpc/quickstart
- Why Edge: https://docs.goldsky.com/edge-rpc/why-edge
- Security: https://docs.goldsky.com/edge-rpc/platform/security
- Monitoring: https://docs.goldsky.com/edge-rpc/platform/monitoring
- Flashblocks: https://docs.goldsky.com/edge-rpc/capabilities/flashblocks
- HyperEVM System Tx: https://docs.goldsky.com/edge-rpc/capabilities/hyperevm-system-transactions
- Error Codes: https://docs.goldsky.com/edge-rpc/evm/error-codes
- Pricing: https://docs.goldsky.com/pricing/summary
- Supported Networks: https://docs.goldsky.com/chains/supported-networks
- eRPC Docs: https://docs.erpc.cloud/
- eRPC GitHub: https://github.com/erpc/erpc
