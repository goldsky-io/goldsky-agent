# Pipeline YAML Structural Validation Checklist

Use this checklist when `goldsky turbo validate` is not available (no Bash tool). Check every applicable item before presenting complete pipeline YAML to the user.

## Top-Level Structure

- [ ] `name` exists and matches pattern: lowercase letters, numbers, hyphens only
- [ ] `resource_size` exists and is one of: `s`, `m`, `l`
- [ ] `sources` section exists and has at least one entry
- [ ] `sinks` section exists and has at least one entry
- [ ] If `job: true`, at least one source has `end_block` (or user explicitly wants processing to chain tip)

## Sources

For each source entry:

- [ ] `type` is specified (`dataset` or `kafka`)
- [ ] For `type: dataset`:
  - [ ] `dataset_name` follows `<chain>.<dataset_type>` format
  - [ ] Chain prefix is valid (`matic` not `polygon`, `bsc` not `binance`, `ethereum` not `eth`)
  - [ ] Dataset type is valid (`raw_transactions` not `transactions`, `raw_logs` not `logs`)
  - [ ] `version` is specified (e.g., `1.0.0`, `1.2.0`)
  - [ ] EVM chains: `start_at` is `earliest` or `latest`
  - [ ] Solana: uses `start_block`, NOT `start_at`

## Transforms

For each transform entry:

- [ ] `type` is one of: `sql`, `script`, `handler`, `dynamic_table`
- [ ] For `type: sql`:
  - [ ] `primary_key` is specified
  - [ ] `sql` field contains a SELECT statement
  - [ ] All table names in `FROM` / `JOIN` reference a source or earlier transform key
- [ ] For `type: script`:
  - [ ] `primary_key`, `language`, `from`, `schema`, and `script` are present
  - [ ] `schema` field types are valid: `string`, `uint64`, `int64`, `float64`, `boolean`, `bytes`
- [ ] For `type: dynamic_table`:
  - [ ] `backend_type` is `Postgres` or `InMemory`
  - [ ] `backend_entity_name` is specified
  - [ ] If `backend_type: Postgres`, `secret_name` is specified
- [ ] For `type: handler`:
  - [ ] `primary_key`, `from`, and `url` are present

## Sinks

For each sink entry:

- [ ] `type` is one of: `postgres`, `postgres_aggregate`, `clickhouse`, `kafka`, `webhook`, `s3_sink`, `s2_sink`, `blackhole`
- [ ] `from` references a valid source or transform key name
- [ ] Required fields by type:
  - `postgres`: `schema`, `table`, `secret_name`, `primary_key`
  - `postgres_aggregate`: `schema`, `landing_table`, `agg_table`, `primary_key`, `secret_name`, `group_by`, `aggregate`
  - `clickhouse`: `table`, `secret_name`, `primary_key`
  - `kafka`: `topic`
  - `s3_sink`: `endpoint`, `bucket`, `secret_name`
  - `s2_sink`: `access_token`, `basin`, `stream`
  - `webhook`: `url` (no `secret_name`)
  - `blackhole`: only `from` required

## Cross-References

- [ ] Every sink `from` value matches exactly one source or transform key
- [ ] Every transform that uses `from` references an existing source or earlier transform
- [ ] No circular references in transform chains
