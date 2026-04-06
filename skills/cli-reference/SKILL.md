---
name: cli-reference
description: "Goldsky CLI command and flag reference — all valid subcommands, arguments, and options for goldsky turbo, pipeline, subgraph, secret, project, dataset, indexed, and telemetry. Consult before suggesting any goldsky command to avoid hallucinating invalid commands or flags."
---

# Goldsky CLI Reference

> Auto-generated from the Goldsky CLI source and turbo binary (turbo 0.9.1).
> Re-run `node scripts/generate-cli-reference.js` to update.

---

## goldsky login / logout

- `goldsky login` — Authenticate with Goldsky
- `goldsky logout` — Remove stored credentials

---

## goldsky turbo

Manages Turbo streaming pipelines. Delegates to the `turbo` binary.

### Subcommands

#### `goldsky turbo apply`

Apply a pipeline definition from YAML file

#### `goldsky turbo delete`

Delete a pipeline by name

#### `goldsky turbo pause`

Pause a pipeline by name

#### `goldsky turbo resume`

Resume a paused pipeline by name

#### `goldsky turbo list`

List all pipelines in the current project

#### `goldsky turbo logs`

Stream logs from a pipeline

#### `goldsky turbo validate`

Validate a pipeline definition without applying it

#### `goldsky turbo inspect`

Inspect live data flowing through a pipeline

#### `goldsky turbo get`

Get pipeline details

#### `goldsky turbo state`

Manage pipeline state

---

## goldsky pipeline

Commands related to Goldsky pipelines

### Subcommands

#### `goldsky pipeline apply <config-path>`

Apply the provided pipeline yaml config. This command creates the pipeline if it doesn

**Arguments:**
- `<config-path>` — path to the yaml pipeline config file. *(required)*

**Options:**
- `--from-snapshot <string>` — Snapshot that will be used to start the pipeline. Applicable values are: 
- `--save-progress` — Attempt a snapshot of the pipeline before applying the update. Only applies if the pipeline already has status: ACTIVE and is running without issues. Defaults to saving progress unless pipeline is being updated to status=INACTIVE.
- `--skip-transform-validation` — skips the validation of the transforms when updating the pipeline. Defaults to false
- `--skip-validation` — skips the validation of the transforms when updating the pipeline. Defaults to false **[deprecated]**
- `--use-latest-snapshot` — attempts to use the latest available snapshot.
- `--status <string>` — Status of the pipeline
- `--force` — Forces apply without any prompts, useful for using apply in CI

#### `goldsky pipeline cancel-update <nameOrConfigPath>`

Cancel in-flight update request

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

#### `goldsky pipeline create <name>`

Create a pipeline

**Arguments:**
- `<name>` — name of the new pipeline *(required)*

**Options:**
- `--output, -outputFormat <string>` — format of the output. Either json or table. Defaults to table. *(default: yaml)*
- `--resource-size, -resourceSize <string>` — runtime resource size for when the pipeline runs *(default: s)* *(required)*
- `--skip-transform-validation` — skips the validation of the transforms when creating the pipeline.
- `--description <string>` — the description of the new pipeline
- `--definition <string>` — definition of the pipeline that includes sources, transforms, sinks. Provided as json eg: 
- `--definition-path <string>` — path to a json/yaml file with the definition of the pipeline that includes sources, transforms, sinks.
- `--status <string>` — the desired status of the pipeline *(default: ACTIVE)*
- `--use-dedicated-ip` — Whether the pipeline should use dedicated egress IPs *(required)*

#### `goldsky pipeline delete <nameOrConfigPath>`

Delete a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

**Options:**
- `--f, -force` — Force the deletion without prompting for confirmation

#### `goldsky pipeline export [name]`

Export pipeline configurations

**Arguments:**
- `[name]` — pipeline name

**Options:**
- `--all` — Export pipeline configurations for all available pipelines

#### `goldsky pipeline get-definition <name>`

**Arguments:**
- `<name>` — pipeline name *(required)*

**Options:**
- `--outputFormat, -output <string>` — format of the output. Either json or yaml. Defaults to yaml. *(default: yaml)* **[deprecated]**

#### `goldsky pipeline get <nameOrConfigPath>`

Get a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

**Options:**
- `--outputFormat, -output <string>` — format of the output. Either json or table. Defaults to json. *(default: yaml)* **[deprecated]**
- `--definition` — print the pipeline
- `--version <string>` — pipeline version. Returns latest version of the pipeline if not set.

#### `goldsky pipeline info <nameOrConfigPath>`

Display pipeline information

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

**Options:**
- `--version <string>` — pipeline version. Returns latest version of the pipeline if not set.

#### `goldsky pipeline list`

List all pipelines

**Options:**
- `--output, -outputFormat <string>` — format of the output. Either json or table. Defaults to json. *(default: table)*
- `--outputVerbosity <string>` — Either summary or all. Defaults to summary. *(default: summary)*
- `--include-runtime-details` — includes runtime details for each pipeline like runtime status and errors. Defaults to false.

#### `goldsky pipeline monitor <nameOrConfigPath>`

Monitor a pipeline runtime

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

**Options:**
- `--version <string>` — pipeline version, uses latest version if not set.
- `--update-request` — monitor update request
- `--max-refreshes, -maxRefreshes <number>` — max. number of data refreshes.

#### `goldsky pipeline pause <nameOrConfigPath>`

Pause a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

#### `goldsky pipeline resize <nameOrConfigPath> <resourceSize>`

Resize a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*
- `<resource-size>` — runtime resource size *(required)*

#### `goldsky pipeline restart <nameOrConfigPath>`

Restart a pipeline. Useful in scenarios where pipeline needs to be restarted without any configuration changes.

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config path *(required)*

**Options:**
- `--from-snapshot <string>` — Snapshot that will be used to start the pipeline. Applicable values are:  *(required)*
- `--disable-monitoring` — Disables monitoring after the command is run. Defaults to false.

#### `goldsky pipeline start <nameOrConfigPath>`

Start a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config path *(required)*

**Options:**
- `--use-latest-snapshot` — attempts to use the latest available snapshot.
- `--from-snapshot <string>` — Snapshot that will be used to start the pipeline. Applicable values are: 

#### `goldsky pipeline stop <nameOrConfigPath>`

Stop a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

#### `goldsky pipeline update <name>`

**Arguments:**
- `<name>` — name of the pipeline to update. *(required)*

**Options:**
- `--outputFormat, -output <string>` — format of the output. Either json or table. Defaults to json. *(default: yaml)* *(required)* **[deprecated]**
- `--resource-size, -resourceSize <string>` — runtime resource size for when the pipeline runs 
- `--status <string>` — status of the pipeline
- `--save-progress` — takes a snapshot of the pipeline before applying the update. Only applies if the pipeline already has status: ACTIVE. Defaults to saving progress unless pipeline is being updated to status=INACTIVE.
- `--skip-transform-validation` — skips the validation of the transforms when updating the pipeline.
- `--use-latest-snapshot` — attempts to use the latest available snapshot.
- `--definition <string>` — definition of the pipeline that includes sources, transforms, sinks. Provided as json eg: 
- `--definition-path <string>` — path to a json/yaml file with the definition of the pipeline that includes sources, transforms, sinks.
- `--description <string>` — description of the pipeline

#### `goldsky pipeline validate [config-path]`

Validate a pipeline definition or config.

**Arguments:**
- `[config-path]` — path to the yaml pipeline config file.

**Options:**
- `--definition <string>` — definition of the pipeline that includes sources, transforms, sinks. Provided as json eg:  **[deprecated]**
- `--definition-path <string>` — path to a json/yaml file with the definition of the pipeline that includes sources, transforms, sinks. **[deprecated]**

#### `goldsky pipeline snapshots`

Commands related to snapshots

##### `goldsky pipeline snapshots create <nameOrConfigPath>`

Attempts to take a snapshot of the pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

##### `goldsky pipeline snapshots list <nameOrConfigPath>`

List snapshots in a pipeline

**Arguments:**
- `<nameOrConfigPath>` — pipeline name or config file path *(required)*

**Options:**
- `--version <string>` — pipeline version. Returns snapshots across all versions if not set.

---

## goldsky subgraph

Commands related to subgraphs

### Subcommands

#### `goldsky subgraph delete <nameAndVersion>`

Delete a subgraph from Goldsky

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--f, -force` — Force the deletion without prompting for confirmation

#### `goldsky subgraph deploy <nameAndVersion>`

Deploy a subgraph to Goldsky

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--path <string>` — Path to subgraph
- `--description <string>` — Description/notes for the subgraph
- `--from-ipfs-hash <string>` — IPFS hash of a publicly deployed subgraph
- `--ipfs-gateway <string>` — IPFS gateway to use if downloading the subgraph from IPFS *(default: https://ipfs.network.thegraph.com)*
- `--from-abi <string>` — Generate a subgraph from an ABI
- `--from-url <string>` — GraphQL endpoint for a publicly deployed subgraph
- `--remove-graft` — Remove grafts from the subgraph prior to deployment
- `--start-block <number>` — Change start block of your subgraph prior to deployment. If used in conjunction with --graft-from, this will be the graft block as well.
- `--graft-from <string>` — Graft from the latest block of an existing subgraph in the format <name>/<version>
- `--enable-call-handlers` — Generate a subgraph from an ABI with call handlers enabled. Only meaningful when used with --from-abi
- `--tag <string>` — Tag the subgraph after deployment, comma separated for multiple tags

#### `goldsky subgraph init [nameAndVersion]`

Initialize a new subgraph project with basic scaffolding

**Arguments:**
- `[nameAndVersion]` — Name and version of the subgraph, e.g. 

**Options:**
- `--target-path <string>` — Target path to write subgraph files to
- `--force` — Overwrite existing files at the target path
- `--from-config <string>` — Path to instant subgraph JSON configuration file
- `--abi <string>` — ABI source(s) for contract(s)
- `--contract <string>` — Contract address(es) to watch for events
- `--contract-events <string>` — Event names to index for the contract(s)
- `--contract-calls <string>` — Call names to index for the contract(s)
- `--network <string>`
- `--contract-name <string>` — Name of the contract(s)
- `--start-block <string>` — Block to start at for a contract on a specific network
- `--description <string>` — Subgraph description
- `--call-handlers` — Enable call handlers for the subgraph
- `--build` — Build the subgraph after writing files
- `--deploy` — Deploy the subgraph after build

#### `goldsky subgraph list [nameAndVersion]`

View deployed subgraphs and tags

**Arguments:**
- `[nameAndVersion]` — Name and version of the subgraph, e.g. 

**Options:**
- `--filter` — Limit results to just tags or deployments *(choices: tags, deployments)*
- `--summary` — Summarize subgraphs & versions without all their details

#### `goldsky subgraph log <nameAndVersion>`

Tail a subgraph

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--since` — Return logs newer than a relative duration like now, 5s, 2m, or 3h *(default: 1m)*
- `--format` — The format used to output logs, use text or json for easier parsed output, use pretty for more readable console output *(choices: pretty, json, text)* *(default: text)*
- `--filter` — The minimum log level to output *(default: info)*
- `--levels` — The explicit comma separated log levels to include (${SubgraphApi.SubgraphLogLevels.join(
- `--interval <number>` — The time in seconds to wait between checking for new logs *(default: 5)*

#### `goldsky subgraph pause <nameAndVersion>`

Pause a subgraph

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

#### `goldsky subgraph start <nameAndVersion>`

Start a subgraph

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

#### `goldsky subgraph update <nameAndVersion>`

Update a subgraph

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--public-endpoint <string>` — Toggle public endpoint for the subgraph *(choices: enabled, disabled)*
- `--private-endpoint <string>` — Toggle private endpoint for the subgraph *(choices: enabled, disabled)*
- `--description <string>` — Description/notes for the subgraph

#### `goldsky subgraph tag`

Commands related to tags

##### `goldsky subgraph tag create <nameAndVersion>`

Create a new tag

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--tag, -t <string>` — The name of the tag *(required)*

##### `goldsky subgraph tag delete <nameAndVersion>`

Delete a tag

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--tag, -t <string>` — The name of the tag to delete *(required)*
- `--f, -force` — Force the deletion without prompting for confirmation

#### `goldsky subgraph webhook`

Commands related to webhooks

##### `goldsky subgraph webhook create <nameAndVersion>`

Create a webhook

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

**Options:**
- `--name <string>` — Name of the webhook, must be unique *(required)*
- `--url <string>` — URL to send events to *(required)*
- `--entity <string>` — Subgraph entity to send events for *(required)*
- `--secret <string>` — The secret you will receive with each webhook request Goldsky sends

##### `goldsky subgraph webhook delete [webhook-name]`

Delete a webhook

**Arguments:**
- `<webhook-name>` — Name of the webhook to delete *(required)*

**Options:**
- `--name <string>` — Name of the webhook to delete **[deprecated]**
- `--f, -force` — Force the deletion without prompting for confirmation

##### `goldsky subgraph webhook list-entities <nameAndVersion>`

List possible webhook entities for a subgraph

**Arguments:**
- `<nameAndVersion>` — Name and version of the subgraph, e.g.  *(required)*

##### `goldsky subgraph webhook list`

List webhooks

---

## goldsky secret

Commands related to secret management

### Subcommands

#### `goldsky secret create`

create a secret

**Options:**
- `--name <string>` — the name of the new secret
- `--value <string>` — the value of the new secret in json
- `--description <string>` — the description of the new secret

#### `goldsky secret delete <name>`

delete a secret

**Arguments:**
- `<name>` — the name of the secret to delete *(required)*

**Options:**
- `--f, -force` — Force the deletion without prompting for confirmation

#### `goldsky secret list`

list all secrets

#### `goldsky secret reveal <name>`

reveal a secret

**Arguments:**
- `<name>` — the name of the secret *(required)*

#### `goldsky secret update <name>`

update a secret

**Arguments:**
- `<name>` — the name of the secret *(required)*

**Options:**
- `--value <string>` — the new value of the secret
- `--description <string>` — the new description of the secret

---

## goldsky project

Commands related to project management

### Subcommands

#### `goldsky project create`

Create a project

**Options:**
- `--name <string>` — the name of the new project *(required)*
- `--team-id <string>` — the ID of the team to create the project in (defaults to current project

#### `goldsky project leave`

Leave a project

**Options:**
- `--projectId <string>` — the ID of the project you want to leave *(required)*

#### `goldsky project list`

List all of the projects you belong to

#### `goldsky project update`

Update a project

**Options:**
- `--name <string>` — the new name of the project *(required)*

#### `goldsky project users`

Commands related to the users of a project

##### `goldsky project users invite`

Invite a user to your project

**Options:**
- `--emails <array>` — emails of users to invite *(required)*
- `--role <string>` — desired role of invited user(s) *(default: Viewer)* *(required)*

##### `goldsky project users list`

List all users for this project

##### `goldsky project users remove`

Remove a user from your project

**Options:**
- `--email <string>` — email of user to remove *(required)*

##### `goldsky project users update`

Update a user

**Options:**
- `--email <string>` — email of user to remove *(required)*
- `--role <string>` — role of user to update *(required)*

---

## goldsky dataset

Commands related to Goldsky datasets

### Subcommands

#### `goldsky dataset get <name>`

Get a dataset

**Arguments:**
- `<name>` — dataset name *(required)*

**Options:**
- `--version <string>` — dataset version
- `--outputFormat <string>` — the output format. Either json or yaml. Defaults to yaml

#### `goldsky dataset list`

List datasets

---

## goldsky indexed

Analyze blockchain data with indexed.xyz

### Subcommands

#### `goldsky indexed rill`

Analyze indexed.xyz data with Rill

#### `goldsky indexed sync`

Commands related to syncing indexed.xyz real-time raw & decoded crypto datasets

##### `goldsky indexed sync checkpoints`

Sync checkpoints (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

##### `goldsky indexed sync decoded-logs`

Sync decoded logs for a smart contract from a network to this computer

**Options:**
- `--contract-address <string>` — The contract address you are interested in
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: ethereum)*

##### `goldsky indexed sync events`

Sync events (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

##### `goldsky indexed sync move-calls`

Sync Move function calls (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

##### `goldsky indexed sync packages`

Sync packages (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

##### `goldsky indexed sync raw-blocks`

Sync all blocks from a network

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: ethereum)*

##### `goldsky indexed sync raw-logs`

Sync all logs from a network

**Options:**
- `--contract-address <string>` — The contract address you are interested in
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: ethereum)*

##### `goldsky indexed sync raw-transactions`

Sync all transactions from a network

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: ethereum)*

##### `goldsky indexed sync sui-transactions`

Sync transactions (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

##### `goldsky indexed sync transaction-objects`

Sync transaction objects (Sui network only)

**Options:**
- `--network <string>` — The network of indexed.xyz data to synchronize *(default: sui)*

---

## goldsky telemetry

Commands related to CLI telemetry

### Subcommands

#### `goldsky telemetry disable`

Disable anonymous CLI telemetry

#### `goldsky telemetry enable`

Enable anonymous CLI telemetry

#### `goldsky telemetry status`

Display the CLI telemetry status
