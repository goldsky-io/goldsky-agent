# Sink Configuration Reference

Complete field reference for all Turbo pipeline sink types.

## Table of Contents

1. [Common Fields](#common-fields)
2. [Blackhole (Testing)](#blackhole-testing)
3. [PostgreSQL](#postgresql)
4. [PostgreSQL Aggregate](#postgresql-aggregate)
5. [ClickHouse](#clickhouse)
6. [Kafka](#kafka)
7. [Webhook](#webhook)
8. [S3](#s3)
9. [S2](#s2)
10. [Multi-Sink Considerations](#multi-sink-considerations)

---

## Common Fields

| Field         | Required | Description                         |
| ------------- | -------- | ----------------------------------- |
| `type`        | Yes      | Sink type                           |
| `from`        | Yes      | Source or transform to read from    |
| `secret_name` | Varies   | Secret for credentials (most sinks) |
| `primary_key` | Varies   | Column for upserts (database sinks) |

---

## Blackhole (Testing)

```yaml
sinks:
  test_output:
    type: blackhole
    from: my_transform
```

No credentials needed. Validates pipeline processing without writing data anywhere.

---

## PostgreSQL

```yaml
sinks:
  postgres_output:
    type: postgres
    from: my_transform
    schema: public
    table: my_table
    secret_name: MY_POSTGRES_SECRET
    primary_key: id
```

**Secret format:** PostgreSQL connection string:
```
postgres://username:password@host:port/database
```

---

## PostgreSQL Aggregate

Real-time aggregations using database triggers. Data flows into a landing table, and a trigger maintains aggregated values in a separate table.

```yaml
sinks:
  balances:
    type: postgres_aggregate
    from: transfers
    schema: public
    landing_table: transfer_log
    agg_table: account_balances
    primary_key: transfer_id
    secret_name: MY_POSTGRES
    group_by:
      account:
        type: text
    aggregate:
      balance:
        from: amount
        fn: sum
```

Supported aggregation functions: `sum`, `count`, `avg`, `min`, `max`

---

## ClickHouse

```yaml
sinks:
  clickhouse_output:
    type: clickhouse
    from: my_transform
    table: my_table
    secret_name: MY_CLICKHOUSE_SECRET
    primary_key: id
```

**Secret format:** ClickHouse connection string:
```
https://username:password@host:port/database
```

Optional: `parallelism: N` for concurrent writers (default `1`).

---

## Kafka

```yaml
sinks:
  kafka_output:
    type: kafka
    from: my_transform
    topic: my-topic
    topic_partitions: 10
    data_format: avro          # or: json
    schema_registry_url: http://schema-registry:8081  # required for avro
```

---

## Webhook

Webhook sinks do **not** use Goldsky's secrets management. Include auth headers directly in the config, or use a plain URL for unauthenticated endpoints.

```yaml
sinks:
  webhook_output:
    type: webhook
    from: my_transform
    url: https://api.example.com/webhook
    one_row_per_request: true
    headers:
      Authorization: Bearer your-token
      Content-Type: application/json
```

Without auth headers:

```yaml
sinks:
  my_webhook:
    type: webhook
    from: my_transform
    url: https://my-lambda.us-west-2.on.aws/
```

---

## S3

```yaml
sinks:
  s3_output:
    type: s3_sink
    from: my_transform
    endpoint: https://s3.amazonaws.com
    bucket: my-bucket
    prefix: data/
    secret_name: MY_S3_SECRET
```

**Secret format:** `access_key_id:secret_access_key` (or `access_key_id:secret_access_key:session_token` for temporary credentials)

---

## S2

Publish to [S2.dev](https://s2.dev) streams — a serverless alternative to Kafka.

```yaml
sinks:
  s2_output:
    type: s2_sink
    from: my_transform
    access_token: your_access_token
    basin: your-basin-name
    stream: your-stream-name
```

---

## Multi-Sink Considerations

- Each sink reads from a `from:` field — different sinks can read from different transforms
- Sinks are independent — one failing doesn't block others
- Use different `batch_size` / `batch_flush_interval` per sink based on latency needs
- ClickHouse supports `parallelism: N` for concurrent writers (default `1`)
