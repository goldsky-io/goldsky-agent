---
name: secrets
description: "Use this skill when a user wants to store, manage, or work with Goldsky secrets — the named credential objects used by pipeline sinks. This includes: creating a new secret from a connection string or credentials, listing or inspecting existing secrets, updating or rotating credentials after a password change, and deleting secrets that are no longer needed. Trigger for any query where the user mentions 'goldsky secret', wants to securely store database credentials for a pipeline, or is working with sink authentication for PostgreSQL, Neon, Supabase, ClickHouse, Kafka, S3, Google Cloud Pub/Sub, Elasticsearch, DynamoDB, SQS, OpenSearch, or webhooks."
---

# Goldsky Secrets Management

Create and manage secrets for pipeline sink credentials.

## Agent Instructions

When this skill is invoked, follow this streamlined workflow:

### Step 1: Verify Login + List Existing Secrets

Run `goldsky secret list` to confirm authentication and show existing secrets.

**If authentication fails:** Invoke the `auth-setup` skill first.

### Step 2: Determine Intent Quickly

**Skip unnecessary questions.** If the user's intent is clear from context, proceed directly:

- User says "create a postgres secret" → Go straight to credential collection
- User pastes a connection string → Parse it immediately (see Connection String Parsing)
- User mentions a specific provider (Neon, Supabase, etc.) → Use provider-specific guidance

**Only use AskUserQuestion if intent is genuinely unclear.**

### Step 3: Connection String Parsing (Preferred for PostgreSQL)

**If user provides a connection string, parse it directly instead of asking questions.**

PostgreSQL connection string format:

```
postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
postgresql://USER:PASSWORD@HOST/DATABASE
```

**Parsing logic:**

1. Extract: `user`, `password`, `host`, `port` (default 5432), `databaseName`
2. Construct JSON immediately
3. Create the secret without further questions

**Example - user provides:**

```
postgresql://neondb_owner:abc123@ep-cool-name.us-east-2.aws.neon.tech/neondb?sslmode=require
```

**Create using the connection string directly:**

```bash
goldsky secret create --name SUGGESTED_NAME
# When prompted, paste the connection string:
# postgresql://neondb_owner:abc123@ep-cool-name.us-east-2.aws.neon.tech/neondb?sslmode=require
```

### Step 4: Provider-Specific Quick Paths

**No database yet? Provision a Goldsky-hosted Postgres (Scale plan or above):**

If the user doesn't already have a Postgres database, Goldsky can provision a managed Postgres (Neon) database and store its credentials as a secret in one step — no external database account required:

```bash
goldsky hosted-sink create --type postgres
```

- `--type postgres` is required; `--name` (auto-generated as `HOSTED_POSTGRES_<RANDOM>` when omitted) and `--description` are optional.
- On success it prints the created secret's **name**, **ID**, and **type**. The connection string is intentionally never printed; reference the secret by **name** as the sink `secret_name`, or run `goldsky secret reveal <name>` to view the connection string later.
- Requires the **Scale plan or above**. Without access the command fails with a Scale-plan upgrade message pointing to the team's billing page — fall back to bringing an external Postgres below.

**Neon:**

- Connection string format: `postgresql://USER:PASS@ep-XXX.REGION.aws.neon.tech/neondb`
- Default port: 5432
- Common issue: Free tier has 512MB limit - pipelines will fail with "project size limit exceeded"

**Supabase:**

- Connection string format: `postgresql://postgres:PASS@db.PROJECT.supabase.co:5432/postgres`
- Use the "Connection string" from Project Settings → Database

**PlanetScale (MySQL):**

- Use `"protocol": "mysql"` and port 3306

### Step 5: Create Secret Directly

Once you have credentials (from parsing or user input), create immediately:

```bash
goldsky secret create \
  --name SECRET_NAME \
  --value '{"type":"jdbc","protocol":"postgres",...}' \
  --description "Optional description"
```

**Naming convention:** `PROJECT_PROVIDER` (e.g., `TRADEWATCH_NEON`, `ANALYTICS_SUPABASE`)

### Step 6: Verify

Run `goldsky secret list` to confirm creation.

---

## Secret Types

Each secret type maps to a `type` field value. For the full field spec and examples of each, see [Secret Formats](https://docs.goldsky.com/turbo-pipelines/pipeline-config#secret-formats) in the docs.

| Secret Type    | Type Field      | Use Case                        |
| -------------- | --------------- | ------------------------------- |
| PostgreSQL     | `jdbc`          | Database sink                   |
| MySQL          | `jdbc`          | Database sink (protocol: mysql) |
| ClickHouse     | `clickHouse`    | Analytics database              |
| Kafka          | `kafka`         | Event streaming                 |
| AWS S3         | `s3`            | Object storage                  |
| Google Pub/Sub | `pubsub`        | GCP Pub/Sub topic (Turbo-only)  |
| ElasticSearch  | `elasticSearch` | Search engine                   |
| DynamoDB       | `dynamodb`      | NoSQL database                  |
| SQS            | `sqs`           | Message queue                   |
| OpenSearch     | `opensearch`    | Search/analytics                |
| Webhook        | `httpauth`      | HTTP endpoints                  |

### Quick Reference Examples

**PostgreSQL** — Connection string format:

```
postgres://username:password@host:port/database
```

```bash
goldsky secret create --name MY_POSTGRES_SECRET
# The CLI will prompt for the connection string interactively
```

**ClickHouse** — Connection string format:

```
https://username:password@host:port/database
```

**Kafka** — JSON format:

```json
{
  "type": "kafka",
  "bootstrapServers": "broker:9092",
  "securityProtocol": "SASL_SSL",
  "saslMechanism": "PLAIN",
  "saslJaasUsername": "user",
  "saslJaasPassword": "pass"
}
```

**S3** — Colon-separated format:

```
access_key_id:secret_access_key
```

Or with session token: `access_key_id:secret_access_key:session_token`

**Google Cloud Pub/Sub** — JSON format (Turbo-only):

```json
{
  "type": "pubsub",
  "projectId": "goldsky-prod",
  "credentialsJson": "{\"type\":\"service_account\",\"project_id\":\"goldsky-prod\",...}"
}
```

The CLI prompts for the GCP project id and asks for the entire service-account JSON key as a single-line paste; it validates the paste is JSON with `type === "service_account"`.

**IAM requirements:** the service account must have **`roles/pubsub.publisher`** AND **`roles/pubsub.viewer`**. The `viewer` role is required by the sink's topic-existence pre-check during initialization — a publish-only SA will fail sink init with a `PermissionDenied` error.

The Pub/Sub topic itself must exist in the GCP project before deploying the pipeline; Goldsky does not auto-create topics.

**Webhook:**

> **Note:** Turbo pipeline webhook sinks do **not** support Goldsky's native secrets management. Include auth headers directly in the pipeline YAML `headers:` field instead.

### Connection String Parser

For PostgreSQL, use the helper script to parse connection strings:

```bash
./scripts/parse-connection-string.sh "postgresql://user:pass@host:5432/dbname"
# Output: JSON ready for goldsky secret create --value
```

### Step 5: Confirm and Create

Show the user what will be created (mask password with \*\*\*) and ask for confirmation before running the command.

### Step 6: Verify Success

Run `goldsky secret list` to confirm the secret was created.

## Quick Reference

| Action | Command                                             |
| ------ | --------------------------------------------------- |
| Create | `goldsky secret create --name NAME --value "value"` |
| List   | `goldsky secret list`                               |
| Reveal | `goldsky secret reveal NAME`                        |
| Update | `goldsky secret update NAME --value "new-value"`    |
| Delete | `goldsky secret delete NAME`                        |

## Prerequisites

- Goldsky CLI installed
- Logged in (`goldsky login`)
- Connection credentials for your target sink

## Why Secrets Are Needed

Pipelines that write to external sinks (PostgreSQL, ClickHouse, Kafka, S3) need credentials to connect. Instead of putting credentials directly in your pipeline YAML, you store them as secrets and reference them by name.

**Benefits:**

- Credentials are encrypted and stored securely
- Pipeline configs can be shared without exposing secrets
- Credentials can be rotated without modifying pipelines

## Command Reference

| Command                        | Purpose             | Key Flags                            |
| ------------------------------ | ------------------- | ------------------------------------ |
| `goldsky secret create`        | Create a new secret | `--name`, `--value`, `--description` |
| `goldsky secret list`          | List all secrets    |                                      |
| `goldsky secret reveal <name>` | Show secret value   |                                      |
| `goldsky secret update <name>` | Update secret value | `--value`, `--description`           |
| `goldsky secret delete <name>` | Delete a secret     | `-f` (force, skip confirmation)      |

## Common Patterns

### PostgreSQL Secret

```bash
goldsky secret create --name PROD_POSTGRES
# When prompted, provide the connection string:
# postgres://admin:secret@db.example.com:5432/mydb
```

Pipeline usage:

```yaml
sinks:
  output:
    type: postgres
    from: my_source
    schema: public
    table: transfers
    secret_name: PROD_POSTGRES
```

### ClickHouse Secret

```bash
goldsky secret create --name CLICKHOUSE_ANALYTICS
# When prompted, provide the connection string:
# https://default:secret@abc123.clickhouse.cloud:8443/analytics
```

Pipeline usage:

```yaml
sinks:
  output:
    type: clickhouse
    from: my_source
    table: events
    secret_name: CLICKHOUSE_ANALYTICS
    primary_key: id
```

### Rotating Credentials

Update an existing secret without changing pipeline configs:

```bash
goldsky secret update MY_POSTGRES_SECRET --value 'postgres://admin:NEW_PASSWORD@db.example.com:5432/mydb'
```

Active pipelines will pick up the new credentials on their next connection.

### Deleting Unused Secrets

```bash
# With confirmation prompt
goldsky secret delete OLD_SECRET

# Skip confirmation (for scripts)
goldsky secret delete OLD_SECRET -f
```

**Warning:** Deleting a secret that's in use will cause pipeline failures.

## Secret Naming Conventions

Use descriptive, uppercase names with underscores:

| Good                 | Bad         |
| -------------------- | ----------- |
| `PROD_POSTGRES_MAIN` | `secret1`   |
| `STAGING_CLICKHOUSE` | `my-secret` |
| `KAFKA_PROD_CLUSTER` | `postgres`  |

Include environment and purpose in the name for clarity.

## Troubleshooting

### Error: Secret not found

```
Error: Secret 'MY_SECRET' not found
```

**Cause:** The secret name doesn't exist or is misspelled.  
**Fix:** Run `goldsky secret list` to see available secrets and check the exact name.

### Error: Secret already exists

```
Error: Secret 'MY_SECRET' already exists
```

**Cause:** Attempting to create a secret with a name that's already in use.  
**Fix:** Use `goldsky secret update MY_SECRET --value "new-value"` to update, or choose a different name.

### Error: Invalid secret value format

```
Error: Invalid JSON in secret value
```

**Cause:** JSON syntax error in the secret value.  
**Fix:** Validate your JSON before creating the secret:

```bash
# Test JSON validity
echo '{"url":"...","user":"..."}' | jq .
```

### Pipeline fails with "connection refused"

**Cause:** The credentials in the secret are incorrect or the database is unreachable.  
**Fix:**

1. Verify credentials work outside Goldsky: `psql "postgresql://..."`
2. Check the secret value: `goldsky secret reveal MY_SECRET`
3. Ensure the database allows connections from Goldsky's IP ranges

### Pipeline fails with "authentication failed"

**Cause:** Username or password in the secret is incorrect.
**Fix:** Update the secret with correct credentials:

```bash
goldsky secret update MY_SECRET --value 'postgres://correct:credentials@host:5432/db'
```

### Secret value contains special characters

**Cause:** JSON strings with special characters need proper escaping.
**Fix:** Use proper JSON escaping for special characters in password fields:

- Backslash: use `\\`
- Double quote: use `\"`
- Newline: use `\n`

With the structured JSON format, most special characters in passwords work without URL encoding since the password is a separate field.

## Related

- **`/turbo-builder`** — Build and deploy pipelines that use these secrets
- **`/auth-setup`** — Invoke this if user is not logged in
- **`/turbo-pipelines`** — Pipeline YAML configuration reference
