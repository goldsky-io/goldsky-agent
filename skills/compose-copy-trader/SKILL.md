---
name: compose-copy-trader
description: "Build and deploy the Goldsky Compose + Turbo copy-trader under the user's own account — a Turbo pipeline indexes Polymarket `OrderFilled` events on Polygon for a set of watched whale wallets and webhooks each fill into a Compose app, which mirrors the trade on the Polymarket CLOB via an EU proxy using a Compose-managed EOA, plus cron tasks that redeem winnings and reconcile state. Triggers on: 'build a copy trader', 'mirror Polymarket trades', 'copy whale wallets', 'Polymarket trading bot', 'follow wallets and copy their bets', 'set up / deploy the copy-trader example', 'compose + turbo webhook trade'. Scaffolds from goldsky-io/copy-trader (the canonical repo), walks CLI install, the two-phase Compose-then-pipeline deploy, the two required secrets, the WATCHED_WALLETS match, funding USDC.e on Polygon, one-time approvals, optional GitHub publish, and synthetic + live smoke tests. This is the most complex example and trades real money on Polygon mainnet. For a custom/novel Compose app, use /compose. For debugging an already-deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose copy-trader

Stand up the copy-trader under the user's own Goldsky account. Two moving parts: a Turbo pipeline (`pipeline/polymarket-ctf-events.yaml`) that indexes Polymarket `OrderFilled` events on Polygon for watched wallets and webhooks them into Compose, and a Compose app (`compose.yaml`) whose tasks mirror each fill and manage positions — `copy_trade` (http; parse fill → Gamma lookup → sign order → POST to CLOB via proxy); `redeem`, `reconcile`, and `pull_trades` (each a 5-minute cron `0 */5 * * * *`, also HTTP-callable); and `setup_approvals`, `status`, `liquidate`, `debug_attempts` (http).

This skill is the single source of truth for the procedure. The canonical, most complete code lives in `goldsky-io/copy-trader` (scaffolded in Step 0); `documentation-examples/compose/copy-trader` is a simplified mirror. This is the most complex example and **trades real money on Polygon mainnet** — do not skip any preflight or ordering step.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot) — NOT a one-click in-app deploy; be explicit about why.** This example is two services plus secrets: a Compose app, a separate **Turbo pipeline** (`goldsky turbo apply`), an app-scoped `PRIVATE_KEY` secret (a real funded Polygon-mainnet EOA), and a project-scoped `COMPOSE_WEBHOOK_AUTH` secret. The `deployComposeApp` card can only deploy the Compose app's files — it cannot apply the pipeline or create those secrets, and the pipeline's webhook needs the app deployed first. So do NOT pretend this deploys from the card. Up front, explain the architecture in plain terms and that it trades **real money on Polygon mainnet**, then **recommend running this one via the local CLI** (`npx skills add goldsky-io/goldsky-agent`, then follow the steps below) where the two-phase deploy + secrets are handled end-to-end. If the user still wants to proceed in-app, you may scaffold + `deployComposeApp` the Compose app, but you MUST then walk them explicitly through the out-of-band steps the card can't do: the two secrets (Step 5–6) and `goldsky turbo apply` for the pipeline (Step 7), in order. Load `/compose-reference` before generating any files.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does; only if asked for steps, output one command at a time. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **Never run `goldsky compose deploy`, `goldsky turbo apply`, `goldsky secret create`, `goldsky compose secret set`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **`WATCHED_WALLETS` must be identical in two places:** the `WATCHED_WALLETS:` env var inside `env.cloud:` of `compose.yaml`, AND the `maker IN (...)` / `taker IN (...)` lists inside the `watched_fills` SQL transform of `pipeline/polymarket-ctf-events.yaml`. Mismatch = fills indexed but not mirrored, or vice versa. Lowercase, comma-separated, identical casing in both.
- **Order of operations matters:** deploy the Compose app *first*, because the pipeline YAML's webhook URL contains the Compose app name. Deploy the pipeline before the app exists (or with a stale name) and every webhook 404s.
- **The `PRIVATE_KEY` secret is a real funded EOA on Polygon mainnet.** Not a testnet. Compose stores it encrypted and uses it only to sign orders. Never print, commit, or log it. CLOB orders execute for real money.
- **US geo-blocking:** Polymarket's CLOB API blocks US IPs and Compose tasks run from `us-west`. The default `CLOB_HOST` (`https://fly-polymarket-proxy.fly.dev`, deployed in Amsterdam) forwards through an EU IP. For production, deploy your own proxy.
- **Compose tasks reach the network only through `ctx.fetch`.** copy-trader ships a `package.json`, so its npm deps are esbuild-bundled and importable for LOCAL use — it signs orders with `viem` and uses `@polymarket/clob-client` only for L1/L2 auth-header crypto (local, no network). The hard limit is the network: tasks get no `--allow-net`, so any SDK that does its own HTTP (axios, node-fetch, the CLOB client's HTTP layer) fails with `getaddrinfo EPERM`. Route every request through `ctx.fetch`; don't "fix" anything by importing an HTTP client.
- **The `OrderFilled` ABI in the pipeline must mark `orderHash`, `maker`, and `taker` as `indexed`** or Turbo silently drops every event.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell with no env carryover from earlier commands.

## Step 0 — Scaffold the example

Pull the canonical copy-trader repo (no git history):

```bash
npx degit goldsky-io/copy-trader copy-trader
cd copy-trader
```

If `npx degit` is unavailable, fall back to `git clone --depth 1 https://github.com/goldsky-io/copy-trader.git`. If the user already cloned it, skip and `cd` in.

## Preflight

1. **`goldsky` CLI** — `goldsky --version`.
2. **`goldsky` authenticated** — `goldsky project list`. If it errors, stop and tell the user: "Please run `goldsky login` in your terminal — browser flow. Tell me to continue when you see the success message." Do not spawn `goldsky login` from Bash.
3. **`node` + `npm`** — `npm --version`. Run `npm install` before anything else; Compose bundles `package-lock.json` deps with esbuild.
4. **`foundry` (optional)** — `cast --version`. Useful for checking USDC.e balance and deriving an address from a private key.

## Step 1 — Configuration interview

Ask one question at a time; translate readable answers to machine values yourself.

1. **"App name?"** (recommend `copy-trader`) → `name:` in `compose.yaml`. Also a path segment in the pipeline's webhook `url:`; renaming means updating both (Step 4).
2. **"Which whale wallets to mirror?"** — one or more Polygon EOAs, lowercase, comma-separated. Require the user to paste them (don't pick for them). Point them at the Polymarket leaderboard for ideas: https://polymarket.com/leaderboard/overall/today/profit.
3. **"Position sizing?"** — the bot sizes each mirror **proportionally**: `WHALE_FRACTION` (default `0.01` = 1% of the whale's notional), floored at the market minimum and **capped at `MAX_TRADE_USD` (default `$25`)**. `TRADE_AMOUNT_USD` is only a legacy fallback (used if `WHALE_FRACTION` is unset). For a safe first run, cap exposure by setting a low `MAX_TRADE_USD` (e.g. `"1"`). Note `WHALE_FRACTION`/`MAX_TRADE_USD` default in code and aren't in the scaffolded `env.cloud` — add them there to override.
4. **"Proxy — shared (default) or your own?"** — default `https://fly-polymarket-proxy.fly.dev` is fine for testing. For production, deploy your own EU proxy and set `CLOB_HOST`.
5. **"EOA that signs CLOB orders — one you control, or a fresh one?"** — this EOA holds USDC.e and signs orders. Fresh: `cast wallet new` prints `(address, private_key)`. Record both.
6. **"Publish to a new GitHub repo?"** — optional.

## Step 2 — Install dependencies

```bash
npm install
```

## Step 3 — Edit `compose.yaml`

Use grep anchors (keys are unique):
- Top-level `name:` → `"<app name>"`
- `env.cloud.WATCHED_WALLETS:` → `"<comma-separated lowercase addresses>"`
- Sizing: add `env.cloud.MAX_TRADE_USD:` → `"1"` for a tiny first-run cap (and optionally `WHALE_FRACTION:`, default `0.01`). `TRADE_AMOUNT_USD` in the scaffold is a legacy fallback only.
- `env.cloud.CLOB_HOST:` → only change if the user has their own proxy.

## Step 4 — Edit `pipeline/polymarket-ctf-events.yaml`

- The pipeline source filters on the Polymarket V2 exchange contracts on Polygon (live since the 2026-04-28 cutover). Both must be in the source `address IN (...)` filter: **CTF Exchange V2 `0xE111180000d2663C0091e4f400237545B87B996B`** and **NegRisk CTF Exchange V2 `0xe2222d279d744050d28e00520010520000310F59`**. The scaffolded YAML already wires these — verify, don't ask the user which exchange to use.
- In the `watched_fills` transform, replace the placeholder address lists in **both** `maker IN (...)` and `taker IN (...)` with the lowercased `WATCHED_WALLETS` addresses. The two lists must match.
- Under `sinks.copy_trade_webhook`, set the `url:` path segment to the app name: `https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/copy_trade`.

## Step 5 — Create the `PRIVATE_KEY` secret

The EOA private key that holds USDC.e and signs orders. **Avoid putting the key on the command line** — `--value "<literal>"` writes it into shell history. Ask the user to paste the key into chat (do not type it yourself), then inline it as a single shell invocation, or set it via the Goldsky dashboard:

```bash
# $EOA_PK never lands in history — set inline, used once, unset:
EOA_PK="0x<paste hex>" goldsky compose secret set PRIVATE_KEY --value "$EOA_PK"; unset EOA_PK
```

App-scoped, declared in the `secrets:` block of `compose.yaml`. `0x` prefix optional.

## Step 6 — Create the `COMPOSE_WEBHOOK_AUTH` secret (project-scoped, one-time)

The pipeline needs a bearer token to POST into the Compose app — a **project-level** secret created once per Goldsky project (skip if it already exists for another pipeline). First create a Compose API token in the dashboard (https://app.goldsky.com); there's no CLI command for that. Then have the user run this in their own terminal (agent Bash has no TTY, so `read -s` won't hide input there):

```bash
read -s COMPOSE_TOKEN
# (paste the token, press Enter; -s hides it)
goldsky secret create --name COMPOSE_WEBHOOK_AUTH \
  --value "{\"type\":\"httpauth\",\"secretKey\":\"Authorization\",\"secretValue\":\"Bearer $COMPOSE_TOKEN\"}"
unset COMPOSE_TOKEN
```

Referenced as `secret_name: COMPOSE_WEBHOOK_AUTH` in the `sinks.copy_trade_webhook` block of the pipeline.

## Step 7 — Deploy Compose app first, then the pipeline

Order matters — see Non-negotiables.

```bash
goldsky compose deploy
```

Capture the deployed app base URL (e.g. `https://api.goldsky.com/api/admin/compose/v1/<app name>/`). Then:

```bash
goldsky turbo apply pipeline/polymarket-ctf-events.yaml
```

The pipeline starts indexing from `latest` (real-time fills).

## Step 8 — Fund the EOA with USDC.e on Polygon

Derive the address: `cast wallet address --private-key "0x<hex>"` → `$EOA_ADDRESS`. Send **USDC.e** (`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174` on Polygon mainnet), starting balance ~$5–10. Note the V2 trading collateral is **pUSD** — `setup_approvals` (Step 9) wraps your USDC.e 1:1 into pUSD via the CollateralOnramp, and the bot checks the pUSD balance before each BUY (skips with `BALANCE_LOW` if pUSD is below ~`tradeAmount × 1.05`). **Do not send MATIC** — Compose sponsors gas; the EOA only needs USDC.e. Verify:

```bash
cast call 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 \
  "balanceOf(address)(uint256)" $EOA_ADDRESS \
  --rpc-url https://polygon-bor-rpc.publicnode.com
# divide by 1e6 for the USDC value
```

## Step 9 — Run one-time approvals

`setup_approvals` does the one-time V2 setup: approve USDC.e → CollateralOnramp, approve pUSD → the V2 exchanges, `setApprovalForAll` on ConditionalTokens → the V2 exchanges, and **wrap** any sitting USDC.e into pUSD. Idempotent. Deployed with `authentication: "auth_token"`, so call it over HTTP with the token from Step 6 (`goldsky compose callTask` only works against local servers):

```bash
curl -X POST -H "Authorization: Bearer $COMPOSE_TOKEN" \
  "https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/setup_approvals"
```

Expect several sponsored on-chain txs (the approvals above + the USDC.e→pUSD wrap). Tail `goldsky compose logs` to confirm.

## Step 10 — Optional: publish to a new GitHub repo

```bash
git init
git add .
# PRIVATE_KEY for a Polygon mainnet EOA holding USDC.e is real money. Abort if
# anything secret-shaped is staged. Fix .gitignore, `git rm --cached`, retry.
git ls-files --cached | grep -iE '(keypair\.json|\.env|private[._-]?key|\.pem|id_rsa)' && \
  { echo "ABORT: secret-shaped file staged"; exit 1; }
git commit -m "Initial commit: Compose copy-trader"
gh repo create <user's repo name> --<public|private> --source=. --push
```

## Step 11 — Smoke test

**Option A — synthetic webhook.** POST a fake fill to `copy_trade`; expect `MARKET_NOT_FOUND` (auth + WATCHED_WALLETS substitution + market-lookup wiring all proved; the fake tokenId just doesn't resolve). This does NOT test the pipeline→webhook path — use Option B for that. Use a real watched wallet for `maker`; if you get `NO_POSITION` instead of `MARKET_NOT_FOUND`, the maker isn't in WATCHED_WALLETS and the test is invalid.

```bash
curl -X POST -H "Authorization: Bearer $COMPOSE_TOKEN" -H "Content-Type: application/json" \
  https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/copy_trade \
  -d '{"id":"test-1","block_number":1,"log_index":0,"transaction_hash":"0xtest","block_timestamp":"2026-01-01T00:00:00Z","maker":"<one watched wallet lowercase>","taker":"0x0000000000000000000000000000000000000000","side":0,"token_id":"999","maker_amount":1,"taker_amount":1,"fee":0}'
# → expect status: "MARKET_NOT_FOUND"
```

**Option B — live test.** Tail `goldsky compose logs` and wait for a real fill on a watched wallet — look for `[copy_trade] TRADE_EXECUTED: BUY <market> — order <id>` or a `BALANCE_LOW` / `MARKET_CLOSED` skip. Also `goldsky turbo logs polymarket-ctf-events` to confirm fills are forwarded. Or hit the `status` task for a JSON snapshot of balance, trades, pnl, and watched wallets.

## Troubleshooting

- **Edits don't take effect after redeploy.** Stale `.compose/` bundle cache. `rm -rf .compose/` and redeploy.
- **Webhook returns 401.** `COMPOSE_WEBHOOK_AUTH` is wrong/missing. Re-create per Step 6.
- **Webhook returns 404.** Pipeline `url:` path segment doesn't match the deployed app name.
- **`copy_trade` returns `BALANCE_LOW`.** The wallet's **pUSD** balance is below ~`tradeAmount × 1.05`. Top up USDC.e and re-run `setup_approvals` (which wraps it into pUSD), or send pUSD directly.
- **`copy_trade` returns `MARKET_NOT_FOUND` for real fills.** Token ID doesn't resolve in Gamma — likely a stale or non-CTF token. Check the fill on Polymarket.
- **`TRADE_FAILED: ... geo-block`.** `CLOB_HOST` isn't routing through the EU. Re-check `CLOB_HOST`; consider a private proxy.
- **`getaddrinfo EPERM` / SDK network errors.** Something is doing HTTP outside `ctx.fetch`. Route it through `ctx.fetch`.
- **Pipeline runs but no webhooks.** Either `WATCHED_WALLETS` casing/format mismatch, or the `OrderFilled` ABI isn't marking `orderHash`/`maker`/`taker` as `indexed` (Turbo drops the events).
- **`TRANSFER_FROM_FAILED` after approvals.** Approvals were done on a different wallet, or `PRIVATE_KEY` changed after approving. Re-run `setup_approvals` with the current key.
- **Redeem doesn't claim winnings.** Check logs for `[redeem] N redeemable positions`. If >0 but txs fail, re-run `setup_approvals`.

## What you should NOT do

- Do not put the private key anywhere other than the `PRIVATE_KEY` secret. Not in `.env`, not on the command line except via `goldsky compose secret set`, never logged.
- Do not change the chain or the Polymarket contract addresses in `src/lib/types.ts`. Polymarket lives on Polygon mainnet only.
- Do not make the `redeem` cron more frequent than its default — Polymarket's data API is cached; hammering it doesn't help.
- Do not delete the `COMPOSE_WEBHOOK_AUTH` secret to rotate it — other pipelines may depend on it. Make a new one and update pipeline YAMLs.
- Do not run from a US IP without the EU proxy. The CLOB will 403 and the first real fill fails silently.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/turbo-pipelines`** — Turbo pipeline YAML, sources, transforms, sinks (the indexing half of this example).
