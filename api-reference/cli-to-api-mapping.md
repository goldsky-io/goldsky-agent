# Goldsky CLI to API Mapping

This document maps Goldsky CLI commands to their REST API equivalents for use with the api-server chatbot endpoint.

**Base URL:** `https://api.goldsky.com`

**Authentication:** Bearer token in `Authorization` header

```bash
curl -H "Authorization: Bearer $GOLDSKY_API_TOKEN" ...
```

---

## Authentication

### Check Token / Login Validation

| CLI Command | `goldsky login` (validates token) |
| ----------- | --------------------------------- |
| Method      | `GET`                             |
| Endpoint    | `/auth/check_token`               |

```bash
curl -X GET "https://api.goldsky.com/auth/check_token" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

---

## Pipelines (Turbo)

### List Pipelines

| CLI Command | `goldsky pipeline list` / `goldsky turbo list` |
| ----------- | ---------------------------------------------- |
| Method      | `GET`                                          |
| Endpoint    | `/api/admin/streams/v1/`                       |

```bash
curl -X GET "https://api.goldsky.com/api/admin/streams/v1/" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Get Pipeline Details

| CLI Command | `goldsky pipeline get <name>` |
| ----------- | ----------------------------- |
| Method      | `GET`                         |
| Endpoint    | `/api/admin/streams/v1/{name}` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

**Query Parameters:**
- `version` - Pipeline version
- `pipelineConfigVersion` - Config version

### Create Pipeline

| CLI Command | `goldsky pipeline create <name>` |
| ----------- | -------------------------------- |
| Method      | `POST`                           |
| Endpoint    | `/api/admin/streams/v1/`         |

```bash
curl -X POST "https://api.goldsky.com/api/admin/streams/v1/" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-pipeline",
    "resourceSize": "s",
    "status": "ACTIVE",
    "definition": { ... }
  }'
```

**Resource Sizes:** `s`, `m`, `l`, `xl`

### Apply Pipeline (Create or Update)

| CLI Command | `goldsky pipeline apply <config-path>` / `goldsky turbo apply` |
| ----------- | -------------------------------------------------------------- |
| Method      | `PUT`                                                          |
| Endpoint    | `/api/admin/streams/v1/{name}`                                 |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-pipeline",
    "sources": { ... },
    "transforms": { ... },
    "sinks": { ... }
  }'
```

### Validate Pipeline

| CLI Command | `goldsky pipeline validate` |
| ----------- | --------------------------- |
| Method      | `POST`                      |
| Endpoint    | `/api/admin/streams/v1/validate` |

```bash
curl -X POST "https://api.goldsky.com/api/admin/streams/v1/validate" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "definition": { ... }
  }'
```

### Delete Pipeline

| CLI Command | `goldsky pipeline delete <name>` / `goldsky turbo delete` |
| ----------- | --------------------------------------------------------- |
| Method      | `DELETE`                                                  |
| Endpoint    | `/api/admin/streams/v1/{name}`                            |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Pause Pipeline

| CLI Command | `goldsky pipeline pause <name>` / `goldsky turbo pause` |
| ----------- | ------------------------------------------------------- |
| Method      | `PUT`                                                   |
| Endpoint    | `/api/admin/streams/v1/{name}`                          |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "PAUSED",
    "save_progress": true
  }'
```

### Start/Resume Pipeline

| CLI Command | `goldsky pipeline start <name>` / `goldsky turbo resume` |
| ----------- | -------------------------------------------------------- |
| Method      | `PUT`                                                    |
| Endpoint    | `/api/admin/streams/v1/{name}`                           |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "ACTIVE"
  }'
```

### Stop Pipeline

| CLI Command | `goldsky pipeline stop <name>` |
| ----------- | ------------------------------ |
| Method      | `PUT`                          |
| Endpoint    | `/api/admin/streams/v1/{name}` |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/streams/v1/my-pipeline" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "INACTIVE"
  }'
```

### Cancel Pipeline Update

| CLI Command | `goldsky pipeline cancel-update <name>` |
| ----------- | --------------------------------------- |
| Method      | `POST`                                  |
| Endpoint    | `/api/admin/streams/v1/{name}/cancel-update` |

```bash
curl -X POST "https://api.goldsky.com/api/admin/streams/v1/my-pipeline/cancel-update" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Get Pipeline Snapshots

| CLI Command | `goldsky pipeline snapshots list <name>` |
| ----------- | ---------------------------------------- |
| Method      | `GET`                                    |
| Endpoint    | `/api/admin/streams/v1/{name}/snapshots` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/streams/v1/my-pipeline/snapshots" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Get Pipeline Runtime Details

| CLI Command | `goldsky pipeline monitor <name>` (internal) |
| ----------- | -------------------------------------------- |
| Method      | `POST`                                       |
| Endpoint    | `/api/admin/streams/v1/runtime-details`      |

```bash
curl -X POST "https://api.goldsky.com/api/admin/streams/v1/runtime-details" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pipelineName": "my-pipeline"
  }'
```

---

## Subgraphs

### List Subgraphs

| CLI Command | `goldsky subgraph list` |
| ----------- | ----------------------- |
| Method      | `GET`                   |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Get Subgraph by Name

| CLI Command | `goldsky subgraph list <name>` |
| ----------- | ------------------------------ |
| Method      | `GET`                          |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs/{name}` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs/my-subgraph" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Get Subgraph Version

| CLI Command | `goldsky subgraph list <name>/<version>` |
| ----------- | ---------------------------------------- |
| Method      | `GET`                                    |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs/{name}/{version}` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs/my-subgraph/1.0.0" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Deploy Subgraph

| CLI Command | `goldsky subgraph deploy <name>/<version>` |
| ----------- | ------------------------------------------ |
| Method      | `POST`                                     |
| Endpoint    | `/api/admin/subgraph/v1/subgraph`          |

```bash
curl -X POST "https://api.goldsky.com/api/admin/subgraph/v1/subgraph" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-subgraph",
    "version": "1.0.0",
    "ipfsHash": "Qm...",
    "description": "My subgraph description"
  }'
```

### Delete Subgraph

| CLI Command | `goldsky subgraph delete <name>/<version>` |
| ----------- | ------------------------------------------ |
| Method      | `DELETE`                                   |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs/{name}/deployments/{version}` |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs/my-subgraph/deployments/1.0.0" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Pause Subgraph

| CLI Command | `goldsky subgraph pause <name>/<version>` |
| ----------- | ----------------------------------------- |
| Method      | `PUT`                                     |
| Endpoint    | `/api/admin/subgraph/v1/subgraph/{name}/{version}/pause` |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/subgraph/v1/subgraph/my-subgraph/1.0.0/pause" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Start Subgraph

| CLI Command | `goldsky subgraph start <name>/<version>` |
| ----------- | ----------------------------------------- |
| Method      | `PUT`                                     |
| Endpoint    | `/api/admin/subgraph/v1/subgraph/{name}/{version}/start` |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/subgraph/v1/subgraph/my-subgraph/1.0.0/start" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Create Subgraph Tag

| CLI Command | `goldsky subgraph tag create <name>/<tag>` |
| ----------- | ------------------------------------------ |
| Method      | `PUT`                                      |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs/{name}/tags/{tag}` |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs/my-subgraph/tags/prod" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "targetVersion": "1.0.0"
  }'
```

### Delete Subgraph Tag

| CLI Command | `goldsky subgraph tag delete <name>/<tag>` |
| ----------- | ------------------------------------------ |
| Method      | `DELETE`                                   |
| Endpoint    | `/api/admin/subgraph/v1/subgraphs/{name}/tags/{tag}` |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/subgraph/v1/subgraphs/my-subgraph/tags/prod" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

---

## Subgraph Webhooks

### List Webhooks

| CLI Command | `goldsky subgraph webhook list` |
| ----------- | ------------------------------- |
| Method      | `GET`                           |
| Endpoint    | `/api/admin/subgraph/v1/webhooks` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/subgraph/v1/webhooks" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Create Webhook

| CLI Command | `goldsky subgraph webhook create <name>/<version>` |
| ----------- | -------------------------------------------------- |
| Method      | `POST`                                             |
| Endpoint    | `/api/admin/subgraph/v1/webhooks/{subgraphName}/{subgraphVersion}` |

```bash
curl -X POST "https://api.goldsky.com/api/admin/subgraph/v1/webhooks/my-subgraph/1.0.0" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-webhook",
    "url": "https://example.com/webhook",
    "entity": "Transfer",
    "secret": "optional-secret"
  }'
```

### Delete Webhook

| CLI Command | `goldsky subgraph webhook delete <name>` |
| ----------- | ---------------------------------------- |
| Method      | `DELETE`                                 |
| Endpoint    | `/api/admin/subgraph/v1/webhooks/{name}` |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/subgraph/v1/webhooks/my-webhook" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

---

## Secrets

### List Secrets

| CLI Command | `goldsky secret list` |
| ----------- | --------------------- |
| Method      | `GET`                 |
| Endpoint    | `/api/admin/secrets/v1/` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/secrets/v1/" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Create Secret

| CLI Command | `goldsky secret create --name NAME --value VALUE` |
| ----------- | ------------------------------------------------- |
| Method      | `POST`                                            |
| Endpoint    | `/api/admin/secrets/v1/`                          |

```bash
curl -X POST "https://api.goldsky.com/api/admin/secrets/v1/" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MY_POSTGRES_SECRET",
    "value": "{\"type\":\"jdbc\",\"protocol\":\"postgres\",\"host\":\"db.example.com\",\"port\":5432,\"databaseName\":\"mydb\",\"user\":\"admin\",\"password\":\"secret\"}",
    "description": "Production PostgreSQL"
  }'
```

**Secret Types:**
- `jdbc` - PostgreSQL, MySQL
- `clickHouse` - ClickHouse
- `kafka` - Kafka
- `s3` - AWS S3
- `elasticSearch` - Elasticsearch
- `opensearch` - OpenSearch
- `dynamodb` - DynamoDB
- `sqs` - AWS SQS
- `httpauth` - Webhook auth

### Reveal Secret

| CLI Command | `goldsky secret reveal <name>` |
| ----------- | ------------------------------ |
| Method      | `GET`                          |
| Endpoint    | `/api/admin/secrets/v1/{name}` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/secrets/v1/MY_POSTGRES_SECRET" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Update Secret

| CLI Command | `goldsky secret update <name> --value VALUE` |
| ----------- | -------------------------------------------- |
| Method      | `PUT`                                        |
| Endpoint    | `/api/admin/secrets/v1/{name}`               |

```bash
curl -X PUT "https://api.goldsky.com/api/admin/secrets/v1/MY_POSTGRES_SECRET" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "value": "new-connection-string",
    "description": "Updated description"
  }'
```

### Delete Secret

| CLI Command | `goldsky secret delete <name>` |
| ----------- | ------------------------------ |
| Method      | `DELETE`                       |
| Endpoint    | `/api/admin/secrets/v1/{name}` |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/secrets/v1/MY_POSTGRES_SECRET" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

---

## Projects

### List Projects

| CLI Command | `goldsky project list` |
| ----------- | ---------------------- |
| Method      | `GET`                  |
| Endpoint    | `/api/admin/project/v1/projects` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/project/v1/projects" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Create Project

| CLI Command | `goldsky project create --name NAME` |
| ----------- | ------------------------------------ |
| Method      | `POST`                               |
| Endpoint    | `/api/admin/project/v1/project`      |

```bash
curl -X POST "https://api.goldsky.com/api/admin/project/v1/project" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-new-project",
    "teamId": "optional-team-id"
  }'
```

### List Project Users

| CLI Command | `goldsky project users list` |
| ----------- | ---------------------------- |
| Method      | `GET`                        |
| Endpoint    | `/api/admin/project/v1/users` |

```bash
curl -X GET "https://api.goldsky.com/api/admin/project/v1/users" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

### Invite User to Project

| CLI Command | `goldsky project users invite --emails USER@EXAMPLE.COM --role Editor` |
| ----------- | ---------------------------------------------------------------------- |
| Method      | `POST`                                                                 |
| Endpoint    | `/api/admin/invite/v1/invite`                                          |

```bash
curl -X POST "https://api.goldsky.com/api/admin/invite/v1/invite" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "emails": ["user@example.com"],
    "role": "Editor"
  }'
```

**Roles:** `Admin`, `Editor`, `Viewer`

### Remove User from Project

| CLI Command | `goldsky project users remove --email USER@EXAMPLE.COM` |
| ----------- | ------------------------------------------------------- |
| Method      | `DELETE`                                                |
| Endpoint    | `/api/admin/project/v1/user`                            |

```bash
curl -X DELETE "https://api.goldsky.com/api/admin/project/v1/user" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com"
  }'
```

---

## Datasets

### List Datasets

| CLI Command | `goldsky dataset list` |
| ----------- | ---------------------- |
| Method      | `GET`                  |
| Endpoint    | `/api/public/datasets/v1` |

```bash
curl -X GET "https://api.goldsky.com/api/public/datasets/v1"
```

> Note: This is a public endpoint, no authentication required.

### Get Dataset Details

| CLI Command | `goldsky dataset get <name>` |
| ----------- | ---------------------------- |
| Method      | `GET`                        |
| Endpoint    | `/api/public/datasets/v1`    |

```bash
curl -X GET "https://api.goldsky.com/api/public/datasets/v1?name=ethereum.decoded_logs"
```

---

## ClickHouse Database

### Get ClickHouse Credentials

| CLI Command | `goldsky db clickhouse connect` |
| ----------- | ------------------------------- |
| Method      | `GET`                           |
| Endpoint    | `/api/admin/secrets/v1/gdb`     |

```bash
curl -X GET "https://api.goldsky.com/api/admin/secrets/v1/gdb" \
  -H "Authorization: Bearer $GOLDSKY_API_TOKEN"
```

---

## API Response Formats

### Success Response

```json
{
  "data": { ... },
  "status": "success"
}
```

### Error Response

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  },
  "status": "error"
}
```

### Common HTTP Status Codes

| Code | Meaning                                     |
| ---- | ------------------------------------------- |
| 200  | Success                                     |
| 201  | Created                                     |
| 400  | Bad Request (invalid parameters)            |
| 401  | Unauthorized (invalid/missing token)        |
| 403  | Forbidden (insufficient permissions)        |
| 404  | Not Found                                   |
| 409  | Conflict (resource already exists)          |
| 500  | Internal Server Error                       |

---

## Headers Reference

All authenticated requests require:

```
Authorization: Bearer $GOLDSKY_API_TOKEN
Content-Type: application/json  # For POST/PUT/PATCH requests
```

Optional headers:
```
User-Agent: goldsky-cli/<version>  # Recommended for tracking
```

---

## Integration Notes for api-server

When integrating with Vercel AI SDK for the chatbot endpoint:

1. **Token Management:** The API token should be passed from the authenticated user session
2. **Request Mapping:** Map natural language intents to the appropriate API calls
3. **Response Formatting:** Transform API responses into user-friendly chat messages
4. **Error Handling:** Convert API errors into helpful suggestions
5. **Rate Limiting:** The API has rate limits; implement appropriate backoff

### Example: Chatbot Intent Mapping

| User Intent | API Call |
| ----------- | -------- |
| "List my pipelines" | `GET /api/admin/streams/v1/` |
| "Create a new pipeline" | `POST /api/admin/streams/v1/` |
| "Delete pipeline X" | `DELETE /api/admin/streams/v1/X` |
| "Show my secrets" | `GET /api/admin/secrets/v1/` |
| "What projects do I have?" | `GET /api/admin/project/v1/projects` |
