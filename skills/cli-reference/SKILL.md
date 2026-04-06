---
name: cli-reference
description: "Goldsky CLI command and flag reference — all valid subcommands, arguments, and options for goldsky turbo, secret, project, and dataset. Consult before suggesting any goldsky command."
---

# Goldsky CLI Reference

> Generated from installed CLI (turbo 0.9.1). Re-run `scripts/generate-cli-reference.sh` to update.

## goldsky turbo

CLI tool for managing Turbo pipelines

### Subcommands

#### `goldsky turbo apply`

Apply a pipeline definition from YAML file

**Arguments:**

    <FILE>  Path to YAML file containing pipeline definition

**Options:**

    -i, --inspect  Open inspect TUI after successful apply

#### `goldsky turbo delete`

Delete a pipeline by name

**Arguments:**

    [NAME]  Pipeline name (required unless -f is used)

**Options:**

    -f, --file <FILE>  Path to YAML file to extract pipeline name from
        --clear-state  Clear state data (default: true)

#### `goldsky turbo pause`

Pause a pipeline by name

**Arguments:**

    [NAME]  Pipeline name (required unless -f is used)

**Options:**

    -f, --file <FILE>  Path to YAML file to extract pipeline name from

#### `goldsky turbo resume`

Resume a paused pipeline by name

**Arguments:**

    [NAME]  Pipeline name (required unless -f is used)

**Options:**

    -f, --file <FILE>  Path to YAML file to extract pipeline name from

#### `goldsky turbo list`

List all pipelines in the current project

**Options:**

        --local-time       Display timestamps in local timezone instead of UTC
    -o, --output <OUTPUT>  Output format: table, json, yaml (default: table) [default: table]

#### `goldsky turbo logs`

Stream logs from a pipeline

**Arguments:**

    <NAME>  Pipeline name

**Options:**

    -f, --follow           Follow log output (like kubectl logs -f)
        --tail <TAIL>      Number of lines from the end of the logs to show
        --since <SINCE>    Show logs from the last N seconds
        --timestamps       Include timestamps on each line
    -o, --output <OUTPUT>  Output format (plaintext or json) [default: plaintext]

#### `goldsky turbo validate`

Validate a pipeline definition without applying it

**Arguments:**

    <FILE>  Path to YAML file containing pipeline definition

#### `goldsky turbo inspect`

Inspect live data flowing through a pipeline

**Arguments:**

    <NAME_OR_FILE>  Pipeline name or path to YAML file

**Options:**

    -n, --topology-node-keys <TOPOLOGY_NODE_KEYS>
    -b, --buffer-size <BUFFER_SIZE>

#### `goldsky turbo get`

Get pipeline details

**Arguments:**

    <NAME_OR_FILE>  Pipeline name or path to YAML file to extract pipeline name from

**Options:**

    -o, --output <OUTPUT>  Output format: yaml, json, table (default: yaml) [default: yaml]

#### `goldsky turbo state`

Manage pipeline state

**Subcommands:** list 

## goldsky secret

Subcommands: create list reveal update delete 

## goldsky project

Subcommands: users leave list update create 

## goldsky dataset

Subcommands: get list 

