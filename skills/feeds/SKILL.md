---
name: feeds
description: "Query Goldsky Feeds, the REST API for one wallet's balances and transfers. Use for wallet holdings, portfolio value, transfer history, deposit checks, edge.goldsky.com/data/feeds, a Feeds API key, or GOLDSKY_FEEDS_API_KEY. There is no goldsky feeds command, and the CLI login token is not this key. For rows in the user's own database, use /turbo-builder. For a Turbo dataset name, use /datasets. For JSON-RPC, use /edge or /boost."
---

# Goldsky Feeds

Feeds answers one question about one wallet over HTTP: what it holds, or what it sent and received, across the supported chains in a single request. Goldsky indexes, normalizes, and prices the rows. The caller does not run a pipeline.

The installed CLI has no feeds command. Do not look for `goldsky feeds`, and do not mint the key with `goldsky edge create`. The endpoint name `feeds` is reserved on the Edge create path, so that command is rejected. The CLI login token is a different credential and does not authenticate these requests.

## When this is the wrong tool

- The rows need to land in the user's own database or webhook. That is a Turbo pipeline (`/turbo-builder`, `/datasets`). Feeds does not stream into a sink; streaming is not offered yet (https://docs.goldsky.com/feeds/streaming).
- The question is a Turbo dataset name or chain prefix. That is `/datasets`. Those prefixes differ: Feeds says `polygon` and `arbitrum_one`, Turbo says `matic` and `arbitrum`.
- The question is JSON-RPC. That is `/edge`, or `/boost` when they want to keep their current provider.

## Key

Create it in the dashboard: https://app.goldsky.com/dashboard/feeds?tab=api-keys. One key covers every feed in the project. Running a test request there creates a key when the project has none.

The user saves it in their own shell:

```bash
export GOLDSKY_FEEDS_API_KEY=your-api-key
```

Do not ask them to paste the key into the chat, do not echo it, and do not write it into a file. If `GOLDSKY_FEEDS_API_KEY` is unset, stop and send them to that dashboard page.

Send the key in the `x-api-key` header. `?key=` and `Authorization: Bearer` are also accepted. Prefer the header so the key does not land in a URL log.

## Calls

Read https://edge.goldsky.com/data/openapi.json before using a parameter or response field that the quickstart does not show. That document is the contract. The guide is https://docs.goldsky.com/feeds/quickstart and the overview is https://docs.goldsky.com/feeds.

Balances returns the latest balance of each token the wallet holds, native assets included, plus `total_value_usd`:

```bash
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/feeds/wallets/balances?address=0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
```

Transfers returns that wallet's movements, newest first. `direction` is `in` or `out` relative to `address`:

```bash
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/feeds/wallets/transfers?address=0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
```

`address` is required and is exactly one wallet. An EVM address is `0x` plus 40 hex digits. A non-200 body is an error, not an empty wallet.

## Parameters

Re-read the OpenAPI spec when a request is rejected. The chain set lives on the `chains` parameter there.

- Omit `chains` to query every supported chain. Pass canonical slugs, comma-separated. `polygon` and `arbitrum_one` are the Feeds names; `matic` and `arbitrum` are Turbo prefixes and are not this parameter.
- `token_symbol` matches a symbol, so two contracts can both match. Use `token_address` when the token must be a specific contract. On balances, the zero address selects the native asset.
- `include_unknown_price` defaults to false, which leaves out tokens Goldsky has no price for.
- `min_value_usd` drops rows below that USD value and also drops unpriced rows. It applies to `total_value_usd` too.
- On transfers, `from` and `to` are inclusive RFC 3339 bounds on `block_timestamp`. `from_block` and `to_block` require exactly one chain, because block numbers are not comparable across chains. `transfer_type` is a comma list of `native`, `erc20`, and `spl`. `direction` is `in` or `out`.
- `page_size` defaults to 100 and the maximum is 1000. The next page is `page_token` set to the previous response's `pagination.next_page_token`. A token is only valid for the filters that produced it. Each page is a separate billed request (https://docs.goldsky.com/pricing/summary#feeds). Do not walk the whole history unless the user asked for that range.

## Writing code against a response

- Balances are the latest amount of each token, not a history. Several transfers in one block become one balance row. Reconstruct movement from the transfers feed.
- A transfer object has no id. Do not build a primary key that includes `block_number` or `block_timestamp`: a transaction that survives a reorg comes back with different block fields. Do not assume one transaction emits a transfer only once.
- `price_usd` and `amount_usd` are computed when the request is served. A later read of the same transfer can show a different USD value.
