# Sink Configuration Reference

Complete field reference for all Turbo pipeline sink types.

## Table of Contents

1. [Common Fields](#common-fields)
2. [Blackhole (Testing)](#blackhole-testing)
3. [PostgreSQL](#postgresql)
4. [PostgreSQL Aggregate](#postgresql-aggregate)
5. [MySQL](#mysql)
6. [ClickHouse](#clickhouse)
7. [Kafka](#kafka)
8. [Pub/Sub](#pubsub)
9. [Webhook](#webhook)
10. [S3](#s3)
11. [SQS](#sqs)
12. [S2](#s2)
13. [Multi-Sink Considerations](#multi-sink-considerations)

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

## MySQL

```yaml
sinks:
  mysql_output:
    type: mysql
    from: my_transform
    schema: my_database       # MySQL treats schema and database as synonyms
    table: my_table
    secret_name: MY_MYSQL_SECRET
    primary_key: id           # Optional — enables upsert (ON DUPLICATE KEY UPDATE)
    # on_conflict: update     # or: nothing (INSERT IGNORE). Only with primary_key.
    # batch_size: 1000
```

| Field          | Required | Description                                                                              |
| -------------- | -------- | ---------------------------------------------------------------------------------------- |
| `type`         | Yes      | `mysql`                                                                                  |
| `from`         | Yes      | Source or transform to read from                                                         |
| `schema`       | Yes      | Database name (MySQL treats `schema` and `database` as synonyms)                         |
| `table`        | Yes      | Table name (auto-created if missing)                                                     |
| `secret_name`  | Yes      | Secret holding MySQL connection fields                                                   |
| `primary_key`  | No       | Column or comma-separated list — when set, inserts become upserts (composite keys ok)    |
| `on_conflict`  | No       | `update` (default, `ON DUPLICATE KEY UPDATE`) or `nothing` (`INSERT IGNORE`)             |
| `batch_size`   | No       | Max rows per `INSERT` statement (default `1000`)                                         |

**Secret format:** structured JSON with `host`, `port`, `user`, `password`, `databaseName`. The `goldsky secret create` flow accepts either a MySQL URL (`mysql://user:pass@host:3306/database`) or individual fields and parses them into the structured shape.

**Behavior notes:**
- Auto-creates the table on startup with `CREATE TABLE IF NOT EXISTS`. No `ALTER TABLE` — adding a new upstream column against an existing table fails the insert.
- Rows with `_gs_op = "d"` are deleted by primary key. With no `primary_key`, deletes are a no-op.
- Arrow → MySQL type mapping: `Int32 → INT`, `Int64 → BIGINT`, `UInt64 → BIGINT UNSIGNED`, `Float64 → DOUBLE`, `Utf8 → TEXT`, `Binary → LONGBLOB`, `Timestamp → DATETIME(6)`, `Date → DATE`, `Decimal(p,s) → DECIMAL(p,s)` (precision capped at 65), nested types (struct/list/map) → `JSON`.

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

## Pub/Sub

Publish records to a [Google Cloud Pub/Sub](https://cloud.google.com/pubsub) topic. **Turbo-only sink** — not available on stream pipelines.

```yaml
sinks:
  pubsub_output:
    type: pubsub
    from: my_transform
    topic: my-topic
    secret_name: MY_PUBSUB_SECRET
    # Optional batching:
    # batch_size: 1000
    # batch_flush_interval: 1s
```

| Field                  | Required | Description                                                              |
| ---------------------- | -------- | ------------------------------------------------------------------------ |
| `type`                 | Yes      | `pubsub`                                                                 |
| `from`                 | Yes      | Source or transform to read from                                         |
| `topic`                | Yes      | Pub/Sub topic name (must already exist in the GCP project)               |
| `secret_name`          | Yes      | Secret holding the GCP project id and service-account JSON               |
| `batch_size`           | No       | Records per batch                                                        |
| `batch_flush_interval` | No       | Max time between flushes (e.g. `1s`, `500ms`)                            |

**Secret format** (`type: pubsub`): a GCP project id and a raw service-account JSON key. See `/secrets` for the create flow. The IAM role on the service account must include **`roles/pubsub.publisher`** AND **`roles/pubsub.viewer`** (the `viewer` role is needed by the sink's topic-existence pre-check during initialization — a publish-only SA will fail sink init with `PermissionDenied`).

The topic must exist in GCP before deploying the pipeline — Goldsky does not auto-create topics.

---

## Webhook

Webhook sinks send rows to an HTTP endpoint with `POST`. Use `secret_name` for a Goldsky `httpauth` secret, inline `headers` for non-secret headers, or a plain URL for unauthenticated endpoints. Do not provide the same header through both `secret_name` and `headers`.

```yaml
sinks:
  webhook_output:
    type: webhook
    from: my_transform
    url: https://api.example.com/webhook
    secret_name: MY_WEBHOOK_SECRET
    one_row_per_request: true
    skip_on_error: true
    headers:
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

| Field                 | Required | Description                                                                 |
| --------------------- | -------- | --------------------------------------------------------------------------- |
| `url`                 | Yes      | Fully-qualified HTTP(S) endpoint URL. Webhook sinks always use HTTP `POST`. |
| `secret_name`         | No       | Name of a Goldsky `httpauth` secret for authenticated webhooks.             |
| `headers`             | No       | Additional non-secret headers. Do not duplicate headers from `secret_name`. |
| `one_row_per_request` | No       | Send one JSON object per request instead of batching rows as a JSON array.  |
| `skip_on_error`       | No       | If `true`, failed deliveries are skipped so the pipeline continues.         |

By default, retriable responses such as timeouts, `408`, `429`, and `5xx` are retried with backoff, while non-retriable `4xx` responses fail the pipeline. Set `skip_on_error: true` only when missing a delivery is acceptable, because skipped rows are not delivered to the endpoint.

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

## SQS

Send each upstream row to Amazon SQS as a JSON message body. Standard queues only — FIFO queues are not supported (the sink does not set `MessageGroupId` or `MessageDeduplicationId`).

```yaml
sinks:
  sqs_output:
    type: sqs_sink
    from: my_transform
    queue_url: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
    secret_name: MY_SQS_SECRET
```

Inline credentials (not recommended for production):

```yaml
sinks:
  sqs_output:
    type: sqs_sink
    from: my_transform
    queue_url: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
    access_key_id: <your-access-key>
    secret_access_key: <your-secret-key>
    region: us-east-1
    # session_token: <sts-token>   # optional, for temporary credentials
    # endpoint_url: <custom-url>   # optional, for SQS-compatible services / VPC endpoints
```

| Field               | Required | Description                                                                          |
| ------------------- | -------- | ------------------------------------------------------------------------------------ |
| `type`              | Yes      | `sqs_sink`                                                                           |
| `from`              | Yes      | Source or transform to read from                                                     |
| `queue_url`         | Yes      | Full SQS queue URL                                                                   |
| `secret_name`       | Varies   | Secret holding `accessKeyId` / `secretAccessKey` / `region` (preferred)              |
| `access_key_id`     | Varies   | Inline AWS access key (omit when using `secret_name`)                                |
| `secret_access_key` | Varies   | Inline AWS secret (omit when using `secret_name`)                                    |
| `region`            | Varies   | AWS region (omit when using `secret_name`)                                           |
| `session_token`     | No       | STS / SSO / assumed-role temporary credentials                                       |
| `endpoint_url`      | No       | Custom SQS endpoint (e.g. VPC endpoint or SQS-compatible service)                    |

**Secret format** (`type: sqs`): JSON with `accessKeyId`, `secretAccessKey`, `region`, and `type: "sqs"`.

**IAM:** the credentials need `sqs:SendMessage` and `sqs:SendMessageBatch` on the target queue.

**Delivery behavior:**
- Uses `SendMessageBatch` with up to 10 messages per request; larger upstream batches are split into 10-message chunks automatically.
- Retries partial-batch failures up to 5 times with exponential backoff (100 ms → 5 s). Sender-fault failures fail immediately without retry.
- SQS rejects messages over 256 KB — drop or truncate wide columns upstream with a SQL transform if payloads approach the limit.

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
