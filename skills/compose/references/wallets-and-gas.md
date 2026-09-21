# Wallets and gas sponsorship

## Wallets — Deep Dive

### Smart wallet (managed, Privy-backed)

```ts
const w = await evm.wallet({ name: "my-oracle" }); // sponsorGas defaults TRUE
```

Created cloud-side by Privy. Address is persisted. **Gas-sponsored by default.** **Cannot be used in plain local dev** - throws `"You cannot use a named wallet without a private key in local dev. Start with "goldsky compose start --fork-chains" for full wallet support, or use a private key wallet: const wallet = await evm.wallet({ privateKey: MY_SECRET }); See https://docs.goldsky.com/compose/secrets for more info on private key wallets"` Use `compose start --fork-chains` or switch to a BYO EOA for local iteration.

### BYO EOA (private key)

```ts
const w = await evm.wallet({
  privateKey: env.MY_KEY,
  name: "my-pk-wallet",       // optional; defaults to the derived address
  sponsorGas: true,           // DEFAULTS TO FALSE — opt in explicitly
});
```

Works in both cloud and local. When `sponsorGas: true`, the wallet configures EIP-7702 delegation per chain on first use, then submits UserOperations through a sponsored bundler.

## Gas Sponsorship

Bundler fallback order: **Alchemy → Pimlico → Gelato**. Override via `BUNDLER_PROVIDER=<alchemy|pimlico|gelato>` env var.

### Supported chains

A chain is runtime-sponsorable if **any** of the three bundler providers covers it (tried in fallback order Alchemy → Pimlico → Gelato, each gated on its API keys being set). In the 0.8.1 source that union spans **112 chains**. This is the **runtime** task-gas sponsorship set - far broader than the `deployContract` / `writeContract` cloud *deploy* path, which covers the 10-chain Alchemy set (1, 11155111, 137, 80002, 42161, 421614, 10, 11155420, 8453, 84532; FOU-991 tracks broader coverage); runtime sponsorship also covers the Arbitrum, Optimism (incl. **Arbitrum Sepolia (`421614`)** / Optimism Sepolia (`11155420`)), Polygon, Ethereum and BNB families, among many others. **Don't hardcode the list** - it changes; confirm current coverage on the Goldsky docs chains page.

### Error on unsupported chain

```
No bundler provider available for chain <id>. Providers: alchemy: chain not supported; pimlico: missing keys (PIMLICO_API_KEY); gelato: …
```

Either use a supported chain or set `sponsorGas: false` and fund the EOA manually.

### Caveats

- `onReorg` is **not** supported for gas-sponsored transactions (warning logged, not fatal).
- Passing a custom `nonce` to a sponsored `sendTransaction` is ignored (ERC-4337 smart wallets use a different nonce structure).

## Supported Chains

`context.evm.chains` is re-exported from `viem/chains`. Any chain viem knows, you can address as `evm.chains.<name>` (e.g. `evm.chains.polygonAmoy`, `evm.chains.monadTestnet`, `evm.chains.baseSepolia`). For **gas sponsorship** specifically, see the Gas Sponsorship section — sponsorship is a subset of viem's chain list.
