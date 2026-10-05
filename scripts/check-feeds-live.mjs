#!/usr/bin/env node
// Checks the Feeds skill's factual claims against the live API.
//
// Why this exists: skills/feeds/SKILL.md asserts specific behaviour, and half
// of that behaviour is invisible in the OpenAPI document — the spec omits
// `spl` from transfer_type, declares no 402, says "max 1000" without saying
// whether an over-max clamps or rejects, and documents no units for the
// Polymarket numeric fields. A docs-vs-skill diff would miss every one of
// those, so the only way to catch drift is to call the API.
//
// Two tiers:
//   spec  — fetches the public openapi.json. No key, no billing, always runs.
//   live  — sends real requests. Needs GOLDSKY_FEEDS_API_KEY. Each request is
//           billed, which is why this is scheduled rather than a PR gate.
// The live tier is skipped (not failed) when the key is absent, so the check
// stays useful in a fork and turns on by itself once the secret exists.

const BASE = "https://edge.goldsky.com/data";
const KEY = process.env.GOLDSKY_FEEDS_API_KEY || "";
const WALLET = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";

const results = [];
const record = (tier, name, ok, detail) => results.push({ tier, name, ok, detail });

async function get(path, { key = KEY } = {}) {
  const res = await fetch(`${BASE}${path}`, { headers: key ? { "x-api-key": key } : {} });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* bare-string error bodies are expected on some paths */ }
  return { status: res.status, json, text };
}

// Compares against a claim the skill makes, so the message names the claim.
function expect(tier, name, actual, wanted) {
  const ok = String(actual) === String(wanted);
  record(tier, name, ok, ok ? String(actual) : `got ${actual}, skill says ${wanted}`);
}

async function specTier() {
  const res = await fetch(`${BASE}/openapi.json`);
  if (!res.ok) { record("spec", "fetch openapi.json", false, `HTTP ${res.status}`); return; }
  const spec = await res.json();
  const paths = Object.keys(spec.paths || {}).sort();

  // The skill's "Other feeds on this key" section enumerates these. A new path
  // appearing here is a capability the skill does not route to yet.
  const known = [
    "/blocks/{chain}", "/blocks/{chain}/head",
    "/feeds/wallets/balances", "/feeds/wallets/transfers",
    "/polymarket/activity", "/polymarket/balances", "/polymarket/positions",
  ].sort();
  expect("spec", "path set unchanged", paths.join(","), known.join(","));

  const walletParams = (p) =>
    (spec.paths[p]?.get?.parameters || []).map((x) => x.name);
  for (const p of ["/feeds/wallets/balances", "/feeds/wallets/transfers"]) {
    const names = walletParams(p);
    for (const required of ["chains", "token_address", "token_symbol", "include_unknown_price", "page_size", "page_token"]) {
      record("spec", `${p} has ${required}`, names.includes(required), names.includes(required) ? "present" : "GONE");
    }
  }
  const balanceParams = walletParams("/feeds/wallets/balances");
  record("spec", "balances has include_historical", balanceParams.includes("include_historical"),
    balanceParams.includes("include_historical") ? "present" : "GONE");

  // The skill tells the reader the wallet feeds serve exactly these 7 chains.
  const chainsDesc = (spec.paths["/feeds/wallets/balances"].get.parameters.find((x) => x.name === "chains")?.description) || "";
  for (const c of ["arbitrum_one", "base", "bsc", "ethereum", "optimism", "polygon", "robinhood"]) {
    record("spec", `wallet chains lists ${c}`, chainsDesc.includes(c), chainsDesc.includes(c) ? "listed" : "MISSING");
  }
}

async function liveTier() {
  // Pass-1 corrections: each of these is a 200 whose empty body would otherwise
  // read as a fact about the wallet.
  const spl = await get(`/feeds/wallets/transfers?address=${WALLET}&transfer_type=spl`);
  expect("live", "transfer_type=spl status", spl.status, 200);
  expect("live", "transfer_type=spl is empty, not an error", spl.json?.data?.length, 0);

  const sol = await get(`/feeds/wallets/balances?address=5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1`);
  expect("live", "solana address accepted", sol.status, 200);

  expect("live", "transfer_type=erc721 rejected",
    (await get(`/feeds/wallets/transfers?address=${WALLET}&transfer_type=erc721`)).status, 400);

  const conflict = await get(`/feeds/wallets/transfers?address=${WALLET}&from_block=20000000`);
  expect("live", "from_block without one chain", conflict.status, 422);
  expect("live", "from_block error code", conflict.json?.error?.code, "CONFLICTING_FILTERS");

  const clamp = await get(`/feeds/wallets/balances?address=${WALLET}&include_unknown_price=true&page_size=1001`);
  expect("live", "page_size over max clamps", clamp.json?.pagination?.page_size, 1000);

  // Auth: the feed answers a missing key with 402 (x402), a wrong key with 401.
  expect("live", "missing key is 402 not 401", (await get(`/feeds/wallets/balances?address=${WALLET}`, { key: "" })).status, 402);
  expect("live", "wrong key is 401", (await get(`/feeds/wallets/balances?address=${WALLET}`, { key: "gs_bogus" })).status, 401);

  // The blocks feed uses a different chain vocabulary than the wallet feeds.
  expect("live", "blocks accepts matic", (await get("/blocks/matic/head")).status, 200);
  expect("live", "blocks rejects polygon", (await get("/blocks/polygon/head")).status, 400);
  expect("live", "wallets accepts polygon", (await get(`/feeds/wallets/balances?address=${WALLET}&chains=polygon&page_size=1`)).status, 200);

  // Polymarket conventions: page_size is silently ignored in favour of limit.
  const ignored = await get("/polymarket/activity?page_size=2");
  expect("live", "polymarket ignores page_size", ignored.json?.data?.length, 100);
  const limited = await get("/polymarket/activity?limit=2");
  expect("live", "polymarket honours limit", limited.json?.data?.length, 2);
  record("live", "polymarket cursor is top-level next_cursor",
    limited.json && "next_cursor" in limited.json && !("pagination" in limited.json),
    limited.json && "next_cursor" in limited.json ? "next_cursor" : "SHAPE CHANGED");

  const unselective = await get("/polymarket/activity?limit=2&event_type=TRADE");
  expect("live", "unselective scan rejected", unselective.status, 400);
  expect("live", "unselective scan code", unselective.json?.error?.code, "MISSING_SELECTIVE_FILTER");

  // Scale: activity is already decimal, positions/balances are 1e6 strings.
  const act = await get("/polymarket/activity?limit=50");
  const fill = (act.json?.data || []).find(
    (r) => r.price != null && r.amount_shares > 0 && r.amount_usdc != null);
  if (!fill) {
    record("live", "activity price is decimal", false, "no priced fill in sample — cannot verify");
  } else {
    record("live", "activity price is a JSON number", typeof fill.price === "number", typeof fill.price);
    const implied = fill.amount_usdc / fill.amount_shares;
    record("live", "activity amount_usdc/amount_shares == price",
      Math.abs(implied - fill.price) < 1e-4, `implied ${implied.toFixed(6)} vs price ${fill.price}`);
  }

  // positions.amount and balances.balance are the same raw 1e6 string.
  const withPos = (act.json?.data || []).filter((r) => r.address && r.token_id);
  let checked = false;
  for (const row of withPos.slice(0, 8)) {
    const pos = await get(`/polymarket/positions?address=${row.address}&token_id=${row.token_id}&limit=1`);
    const p = pos.json?.data?.[0];
    if (!p) continue;
    record("live", "positions.amount is a string", typeof p.amount === "string", typeof p.amount);
    const bal = await get(`/polymarket/balances?address=${row.address}&token_id=${row.token_id}&limit=1`);
    const b = bal.json?.data?.[0];
    // Deliberately NOT asserting amount === balance. They share the 1e6 scale
    // but count different things (trade-derived position vs tokens held), and
    // they disagree on roughly half of real rows. Assert only the scale.
    if (b) record("live", "balances.balance is a 1e6 string", typeof b.balance === "string" && /^\d+$/.test(b.balance), `${typeof b.balance} ${b.balance}`);
    // A 0-1 prediction-market price only makes sense at 1e6.
    const scaled = Number(p.avg_price) / 1e6;
    record("live", "positions.avg_price is 1e6-scaled", scaled >= 0 && scaled <= 1, `avg_price ${p.avg_price} -> ${scaled}`);
    checked = true;
    break;
  }
  if (!checked) record("live", "polymarket position scales", false, "no sampled fill had a matching position");
}

await specTier();
if (KEY) {
  await liveTier();
} else {
  console.log("GOLDSKY_FEEDS_API_KEY not set — live tier skipped (spec tier still ran).\n");
}

let failed = 0;
for (const tier of ["spec", "live"]) {
  const rows = results.filter((r) => r.tier === tier);
  if (!rows.length) continue;
  console.log(`[${tier}]`);
  for (const r of rows) {
    if (!r.ok) failed++;
    console.log(`  ${r.ok ? "ok  " : "DRIFT"}  ${r.name}${r.ok ? "" : `  — ${r.detail}`}`);
  }
}
console.log(`\n${results.length - failed} ok, ${failed} drifted`);
if (failed) {
  console.log("\nThe live API no longer matches what skills/feeds/SKILL.md tells an agent.");
  console.log("Re-read https://edge.goldsky.com/data/openapi.json, confirm by calling the path, and correct the skill.");
  process.exit(1);
}
