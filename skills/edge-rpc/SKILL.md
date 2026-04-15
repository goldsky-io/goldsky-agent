---
name: edge-rpc
description: "Set up, configure, and debug Goldsky Edge RPC endpoints. Triggers on: 'set up Edge RPC', 'get an RPC endpoint', 'RPC endpoint not working', 'Edge RPC error', 'rate limit exceeded', 'how to use Edge RPC', 'connect viem to Goldsky', 'connect ethers to Goldsky', 'RPC 401 unauthorized', 'RPC timeout', 'stale data from RPC', 'Edge RPC latency', 'flashblocks', 'HyperEVM system transactions', 'which chains does Edge support', 'Edge RPC pricing', 'configure rate limiting', 'RPC authentication', 'eth_getLogs missing data', 'need an RPC provider'. Also use when the user wants high-performance RPC access for EVM chains, needs to replace their current RPC provider, or is debugging JSON-RPC errors from an Edge endpoint. For streaming blockchain data into a database, use turbo-builder instead."
---

# Edge RPC

## Boundaries

- Set up, configure, and debug **Edge RPC endpoints** for EVM chains.
- Do not build data pipelines — that belongs to `/turbo-builder`.
- Do not manage subgraphs — that belongs to `/subgraphs`.
- Do not serve as a general Goldsky CLI reference — this skill is specifically for Edge RPC.

Edge RPC provides high-performance, multi-region RPC access with sub-100ms latency, automatic failover, cross-validation, and built-in observability. It is built on top of [eRPC](https://erpc.cloud), an open-source EVM RPC proxy.

## Mode Detection

Before running any commands, check if you have the `Bash` tool available:

- **If Bash is available** (CLI mode): Execute `curl` commands directly and parse output.
- **If Bash is NOT available** (reference mode): Output commands for the user to run. Ask them to paste the output back so you can analyze it.

---

## Setup Workflow

Follow these steps in order when the user wants to set up Edge RPC.

### Step 1: Verify Goldsky Account

Edge RPC requires a Goldsky account. Ask the user if they have one:

- **Has an account:** Continue to Step 2.
- **No account:** Direct them to create one at https://app.goldsky.com (free to create). Use the `/auth-setup` skill if they also need the CLI installed, though the CLI is not strictly required for Edge RPC usage.

### Step 2: Get the API Secret

The user needs their API secret from the Goldsky dashboard.

```
You'll need your Edge RPC secret from the dashboard:

1. Go to https://app.goldsky.com
2. Navigate to Settings → Edge RPC (or API Keys)
3. Copy your secret token

Paste it here when you're ready.
```

Wait for the user to provide their secret before continuing.

### Step 3: Identify the Chain

Ask which chain the user wants to connect to. Help them find the right chain ID from the supported networks:

| Network | Chain ID | Network | Chain ID |
| ------- | -------- | ------- | -------- |
| Ethereum | 1 | Arbitrum One | 42161 |
| Base | 8453 | Optimism | 10 |
| Polygon zkEVM | 1101 | Avalanche | 43114 |
| BSC | 56 | Linea | 59144 |
| Scroll | 534352 | Sonic | 146 |
| Blast | 81457 | zkSync | 324 |
| Monad | 143 | Berachain | 80094 |
| HyperEVM | 999 | Zora | 7777777 |
| Swell | 1923 | Sei | 1329 |
| Unichain | 130 | Gnosis | 100 |
| Kaia | 8217 | Gravity | 1625 |
| Flare | 14 | Cyber | 7560 |
| Kava | 2222 | Zircuit | 48900 |
| Abstract | 2741 | | |

Testnets: Base Sepolia (84532), Arbitrum Sepolia (421614), Optimism Sepolia (11155420), Monad Testnet (10143), HyperEVM Testnet (998), Unichain Testnet (1301), Somnia Testnet (50312).

If the user's chain isn't listed, tell them to contact sales@goldsky.com.

### Step 4: Construct the Endpoint URL

Edge RPC endpoints follow this format:

```
https://edge.goldsky.com/standard/evm/{chainId}?secret=YOUR_SECRET
```

Replace `{chainId}` with the chain ID and `YOUR_SECRET` with the API secret.

**Example for Ethereum Mainnet:**

```
https://edge.goldsky.com/standard/evm/1?secret=abc123
```

### Step 5: Verify the Endpoint

Test the endpoint with a simple `eth_blockNumber` call:

```bash
curl "https://edge.goldsky.com/standard/evm/{chainId}?secret=YOUR_SECRET" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

**Success:** Response contains `"result"` with a hex block number (e.g., `"0x134a1b0"`).

**Failure indicators:**
- `401` or `Unauthorized` — Invalid or missing secret
- `404` — Chain ID not supported
- Connection timeout — Network issue, retry

### Step 6: Provide Integration Code

Based on the user's framework, provide the appropriate integration snippet:

**viem:**
```javascript
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http('https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET')
})

const blockNumber = await client.getBlockNumber()
```

**ethers.js:**
```javascript
import { JsonRpcProvider } from 'ethers'

const provider = new JsonRpcProvider(
  'https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET'
)

const blockNumber = await provider.getBlockNumber()
```

**web3.js:**
```javascript
import Web3 from 'web3'

const web3 = new Web3(
  'https://edge.goldsky.com/standard/evm/1?secret=YOUR_SECRET'
)

const blockNumber = await web3.eth.getBlockNumber()
```

### Step 7: Completion Summary

```
## Edge RPC Setup Complete

**Endpoint:** https://edge.goldsky.com/standard/evm/{chainId}?secret=***
**Network:** [network name] (Chain ID: [id])

**What you get:**
- Sub-100ms latency from 8+ edge regions
- Automatic failover across multiple providers
- Cross-validation for data integrity
- $5 per million requests, all methods priced equally

**Next steps:**
- Visit the Grafana dashboard in app.goldsky.com for real-time monitoring
- Configure rate limiting in Settings → Edge RPC
- See /edge-rpc for debugging help if you run into issues
```

---

## Authentication

Edge RPC supports two authentication methods:

**Query parameter (default):**
```
https://edge.goldsky.com/standard/evm/{chainId}?secret=YOUR_SECRET
```

**Header-based** (better for logs/security — secret not in URL):
```bash
curl "https://edge.goldsky.com/standard/evm/1" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-ERPC-Secret-Token: YOUR_SECRET" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

Recommend header-based auth when the user is concerned about secrets in URLs, access logs, or browser history.

---

## Rate Limiting

Rate limits are configured per secret in the Goldsky Dashboard. Available tiers:

| Tier | Total RPS | Per-IP RPS | Use Case |
| ---- | --------- | ---------- | -------- |
| None (Unlimited) | Unlimited | Unlimited | No rate limiting |
| 6k RPM total | ~100 | Unlimited | Low volume |
| 60k RPM total | ~1,000 | Unlimited | Medium volume |
| 180k RPM total | ~3,000 | Unlimited | High volume |
| 360k RPM total | ~6,000 | Unlimited | Very high volume |
| 600k RPM total | ~10,000 | Unlimited | Enterprise volume |

Per-IP variants are available for each tier (adds ~8 RPS or ~1.7 RPS per-IP cap) — useful when exposing the endpoint to end users.

---

## Special Capabilities

### Flashblocks (OP Stack Chains)

Faster block confirmations via pre-confirmed blocks before L1 finalization. Add `use-upstream=flashblocks*` to the URL:

```
https://edge.goldsky.com/standard/evm/8453?secret=YOUR_SECRET&use-upstream=flashblocks*
```

Or as a header:
```
X-ERPC-Use-Upstream: flashblocks*
```

**Supported:** Base (8453), Base Sepolia (84532), Optimism (10), Optimism Sepolia (11155420), Unichain (130), Unichain Testnet (1301).

### HyperEVM Node Routing

HyperEVM (Chain ID: 999) has two distinct node pools:

| Type | Upstream | Description | Use Case |
| ---- | -------- | ----------- | -------- |
| Archive | `systx*` | Full archive nodes, includes system transactions | Indexing, historical queries, debugging |
| Realtime | `standard*` | Optimized for speed, excludes system transactions | Frontend dApps, realtime data |

**Important:** If you don't specify a node type, requests may load-balance across both pools, causing **inconsistent results**.

```
# Archive (with system transactions)
https://edge.goldsky.com/standard/evm/999?secret=YOUR_SECRET&use-upstream=systx*

# Realtime (without system transactions)
https://edge.goldsky.com/standard/evm/999?secret=YOUR_SECRET&use-upstream=standard*
```

---

## Debugging Workflow

Follow these steps when the user reports an Edge RPC issue.

### Step 1: Identify the Error

Ask the user for:
1. The exact error message or HTTP status code
2. Which chain and method they're calling
3. Whether it was working before (regression vs. first-time setup)

### Step 2: Match the Error Pattern

| Error | Code | Cause | Fix |
| ----- | ---- | ----- | --- |
| Unauthorized | -32016 or HTTP 401 | Invalid or missing secret | Verify secret in dashboard, check for typos, try header-based auth |
| Rate limit exceeded | -32005 | Too many requests | Check rate limit tier in dashboard, upgrade tier, implement client-side backoff |
| Range too large | -32012 | `eth_getLogs` block range too wide | Reduce block range (Edge auto-splits, but extreme ranges still fail) |
| Missing data | -32014 | Block/tx/state not found | May be pruned — confirm archive access, check block number is valid |
| Node timeout | -32015 | Upstream provider timed out | Retry — Edge will automatically failover. If persistent, contact support |
| Parse error | -32700 | Invalid JSON in request body | Check JSON formatting, ensure Content-Type is application/json |
| Invalid request | -32600 | Missing JSON-RPC fields | Ensure request has `jsonrpc`, `method`, `params`, and `id` fields |
| Method not found | -32601 | Unsupported RPC method | Check method name spelling, verify method is supported for the chain |
| Invalid params | -32602 | Wrong parameter types or count | Review method params — common issues: missing `0x` prefix on hex values, wrong param order |
| Call exception | -32000 | Contract call reverted or out of gas | Check contract address, verify ABI, test with a known-good call |
| Execution reverted | 3 | Contract logic reverted | Decode revert reason, check contract state and function inputs |

### Step 3: Run a Diagnostic Test

If the cause isn't clear, run a minimal test to isolate the issue:

```bash
# Basic connectivity test
curl -s -o /dev/null -w "%{http_code}" \
  "https://edge.goldsky.com/standard/evm/{chainId}?secret=YOUR_SECRET" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

- **200** — Endpoint is reachable, issue is method/params-specific
- **401** — Auth failure
- **429** — Rate limited
- **5xx** — Server-side issue, retry or contact support

Then test the specific method the user is having trouble with.

### Step 4: Check for Common Pitfalls

- **Stale data:** Edge cross-validates across providers. If the user sees data behind tip, check if they're using a method that hits cache (like `eth_getBlockByNumber("latest")`) — this is by design for consistency.
- **Inconsistent HyperEVM results:** User must pin to `systx*` or `standard*` upstream — without this, requests bounce between archive and realtime pools.
- **eth_getLogs returning partial data:** Edge auto-splits large ranges, but verify block range isn't excessively wide. Check that `fromBlock`/`toBlock` params are correct.
- **WebSocket not available:** Edge RPC is HTTP-only for most methods. For `eth_subscribe`/`eth_unsubscribe`, verify the chain supports it via Edge.
- **Secret in browser-visible URL:** Recommend switching to header-based auth (`X-ERPC-Secret-Token`) for frontend apps.

### Step 5: Provide Diagnosis

Present findings in this format:

```
## Diagnosis

**Endpoint:** [chain + chain ID]
**Method:** [RPC method]
**Issue:** [one-line summary]

**Root cause:**
[Detailed explanation]

**Evidence:**
- [Error message or observation 1]
- [Error message or observation 2]

**Fix:**
1. [Step 1]
2. [Step 2]

**Prevention:**
[How to avoid this in the future]
```

### Step 6: Offer to Fix

If the fix involves updating the request format, changing auth method, adjusting rate limits, or switching upstream routing — provide the corrected code or curl command directly.

For dashboard-level changes (rate limit tier, secret rotation), walk the user through the dashboard UI.

---

## Monitoring

Edge RPC includes built-in Grafana dashboards accessible from the Goldsky dashboard. Key metrics:

- **Overall:** Total RPC requests with time-series trends
- **Usage:** Request volume by network, method distribution
- **Performance:** P50/P90/P99 response times by network
- **Errors:** Critical errors, warnings, and notices by network and error type
- **Efficiency:** Multiplexed (deduplicated) requests, hedge effectiveness, rate-limited requests
- **Finality:** Distribution of finalized vs. real-time responses

When debugging performance issues, direct the user to the Grafana dashboard for real-time visibility.

---

## Pricing

- **$5 per million requests** — all methods priced equally
- No surprise charges for expensive methods like `eth_getLogs` or `trace_*`
- Volume discounts available for 500M+ requests/month
- Free tier available on the Starter plan

---

## Error Response Format

All Edge RPC errors follow standard JSON-RPC format:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params"
  }
}
```

Edge normalizes errors from different upstream providers to consistent codes, so the user always gets predictable error handling regardless of which backend served the request.

---

## Important Rules

- Always verify the user's secret works before diving into complex debugging — auth issues are the most common problem.
- Never expose or log the user's secret token in output. Mask it in summaries (e.g., `secret=***`).
- For HyperEVM users, always ask whether they need archive or realtime data — inconsistent results from not pinning upstreams is a frequent pain point.
- If the user's chain isn't supported, direct them to sales@goldsky.com rather than guessing.
- Edge RPC is HTTP-based JSON-RPC. Do not suggest WebSocket-specific patterns unless the method explicitly supports it.
- If the issue appears to be on Goldsky's infrastructure side (persistent 5xx errors, widespread timeouts), suggest contacting support@goldsky.com with the error details.

## Related

- **`/auth-setup`** — Install the Goldsky CLI and authenticate (not required for Edge RPC, but useful for pipelines)
- **`/turbo-builder`** — Stream blockchain data into databases instead of querying via RPC
- **`/datasets`** — Find chain names and prefixes for Turbo pipelines
- **Goldsky docs:** [docs.goldsky.com/edge-rpc/introduction](https://docs.goldsky.com/edge-rpc/introduction)
