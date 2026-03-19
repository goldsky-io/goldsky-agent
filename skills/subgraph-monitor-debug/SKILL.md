---
name: subgraph-monitor-debug
description: "Use this skill when the user needs to look up goldsky subgraph CLI syntax — flags and options for log, list, or status commands — or wants to understand what a specific subgraph error message means (store errors, IPFS timeouts, mapping failures, stalled subgraph notifications, 524 errors, column conflicts, graft errors). Also use for understanding stalled subgraph detection behavior and auto-pause policies. Distinguishing factor: this skill provides reference information and explanations. If the user has a broken subgraph and wants step-by-step interactive diagnosis, use /subgraph-doctor instead."
---

# Subgraph Monitoring & Debugging Reference

CLI commands, error patterns, and troubleshooting reference for Goldsky subgraphs. For interactive subgraph diagnosis (running commands, checking logs, walking through fixes), use `/subgraph-doctor` instead.

---

## Quick Reference

| Action | Command |
| ------ | ------- |
| List all subgraphs | `goldsky subgraph list` |
| List specific subgraph | `goldsky subgraph list name/version` |
| View logs | `goldsky subgraph log name/version` |
| Pause subgraph | `goldsky subgraph pause name/version` |
| Start/resume subgraph | `goldsky subgraph start name/version` |
| Delete subgraph | `goldsky subgraph delete name/version` |

---

## Error Pattern Reference

> **Detailed error patterns and solutions are in the `data/` folder.**

| File | Contents |
| ---- | -------- |
| `error-patterns.json` | All known error patterns with causes and solutions |

---

## Common Error Patterns

| Error Pattern | Likely Cause | Fix |
| ------------- | ------------ | --- |
| `column "x" specified more than once` | ABI name conflicts in instant subgraph config | Rename conflicting ABI entries or use distinct contract names |
| `524 timeout` | IPFS metadata timeout during deployment | Retry deployment; if persistent, check IPFS hash or use `--ipfs-gateway` |
| Mapping/handler crash | AssemblyScript runtime error in event handler | Check handler code for null access, overflow, or missing entity loads |
| `store error` | Entity store write failure | Check for duplicate entity IDs or schema conflicts |
| Graft error | Incompatible graft base or missing graft source | Use `--remove-graft` or verify the graft source exists |
| Subgraph stalled | Indexing stopped making progress | Check logs for handler errors; may need code fix and redeploy |
| RPC errors | Upstream node issues | Usually transient — Goldsky's load balancer retries automatically |
| `subgraph not found` | Wrong name/version or wrong project | Verify with `goldsky subgraph list` and `goldsky project list` |

---

## Stalled Subgraph Detection

Goldsky automatically monitors subgraphs for indexing issues:

### How It Works

1. **Warning stage:** If a subgraph stops making progress, Goldsky sends a stall warning notification
2. **Auto-pause stage:** If the stall persists, the subgraph is automatically paused to prevent resource waste

### When You Receive a Stall Notification

1. **Check status:** `goldsky subgraph list name/version` or view in the Goldsky dashboard
2. **Review logs:** `goldsky subgraph log name/version` — look for errors or warnings
3. **Common fixes:**
   - Update mapping code to handle edge cases
   - Fix bugs in AssemblyScript handlers
   - Adjust subgraph manifest configuration
4. **Resume or redeploy:**
   - If paused: `goldsky subgraph start name/version`
   - If code changes needed: `goldsky subgraph deploy name/new-version --path .`
5. **Monitor recovery:** Verify the subgraph is making progress again

---

## Mapping/Handler Issues

| Issue | Fix |
| ----- | --- |
| Null entity access | Always check `entity != null` before accessing fields |
| BigInt overflow | Use `BigInt` type, not `i32`/`i64` for large numbers |
| Missing entity load | Call `Entity.load(id)` before accessing — entities may not exist yet |
| Event parameter mismatch | Ensure event signature in subgraph.yaml matches the actual ABI exactly |
| `store.set` with wrong type | Entity field types must match schema.graphql exactly |

---

## Deployment Issues

| Issue | Fix |
| ----- | --- |
| `524 timeout` on deploy | IPFS download timeout — retry, or use a different `--ipfs-gateway` |
| ABI column conflicts | Rename ABI entries in instant config to avoid duplicate event/field names |
| Build fails | Check AssemblyScript compilation errors in the build output |
| Wrong chain slug | Subgraphs use `mainnet` (not `ethereum`), `matic` (not `polygon`), `xdai` (not `gnosis`) |

---

## Common Issues Quick Reference

| Symptom | Likely Cause | Quick Fix |
| ------- | ------------ | --------- |
| Subgraph not syncing | Handler error or stalled | Check logs for errors |
| GraphQL returns stale data | Subgraph paused or stalled | Check status, resume if paused |
| No data at all | Wrong start block or chain | Verify config in `/subgraph-config` |
| 524 error on queries | Subgraph overloaded or down | Check status; contact support if persistent |
| Wrong entities indexed | ABI mismatch | Verify ABI matches deployed contract |
| Endpoint returns 401 | Missing/invalid API key | Use Bearer token for private endpoints |

---

## When to Contact Support

Contact support@goldsky.com when:
- Stalled subgraph with no errors in logs
- Persistent 524 timeouts on queries (not deployment)
- Data inconsistencies between chain and subgraph
- Custom chain or dedicated indexer issues
- Billing or resource limit questions

---

## Related

- **`/subgraph-doctor`** — Interactive diagnostic skill for troubleshooting subgraphs
- **`/subgraph-builder`** — Deploy new subgraphs
- **`/subgraph-lifecycle`** — Pause, start, delete, tag commands
- **`/subgraph-config`** — Configuration reference
