#!/usr/bin/env node
/**
 * generate-cli-reference — Generates skills/cli-reference/SKILL.md from the
 * Goldsky CLI TypeScript source + the installed turbo binary.
 *
 * Usage:
 *   node scripts/generate-cli-reference.js [--cli-source <path>]
 *
 * Defaults cli-source to ../goldsky-5/packages/cli/src relative to this script.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ── Config ─────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const cliSourceArg = args.indexOf("--cli-source");
const CLI_SOURCE =
  cliSourceArg >= 0
    ? args[cliSourceArg + 1]
    : path.resolve(__dirname, "../../goldsky-5/packages/cli/src");

const OUTPUT = path.resolve(__dirname, "../skills/cli-reference/SKILL.md");
const COMMANDS_DIR = path.join(CLI_SOURCE, "commands");

if (!fs.existsSync(COMMANDS_DIR)) {
  console.error(`CLI source not found at: ${COMMANDS_DIR}`);
  console.error(`Run with: node scripts/generate-cli-reference.js --cli-source <path-to-cli/src>`);
  process.exit(1);
}

// ── TypeScript source parsing ───────────────────────────────────────────────

function readFile(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, "utf8");
}

/** Extract a top-level export const value (string only) */
function extractStringExport(src, name) {
  const match = src.match(new RegExp(`export const ${name}\\s*=\\s*["'\`]([^"'\`]+)["'\`]`));
  return match ? match[1] : null;
}

/** Check if command/describe indicates deprecation */
function isDeprecated(describe) {
  if (!describe) return false;
  return describe.toLowerCase().includes("[deprecated]") || describe.toLowerCase().includes("deprecated");
}

/**
 * Extract all .option() and .positional() calls from a builder function.
 * Returns arrays of { name, describe, type, alias, default, choices, demandOption, deprecated, hidden }
 */
function extractBuilderCalls(src) {
  const options = [];
  const positionals = [];

  // Find all .option('name', { ... }) and .positional('name', { ... }) blocks
  // We scan character by character to handle nested braces
  const methodRe = /\.(option|positional)\s*\(\s*["']([^"']+)["']\s*,\s*\{/g;
  let match;

  while ((match = methodRe.exec(src)) !== null) {
    const methodType = match[1]; // "option" or "positional"
    const optName = match[2];
    const blockStart = match.index + match[0].length - 1; // position of opening {

    // Walk forward to find matching closing }
    let depth = 0;
    let i = blockStart;
    while (i < src.length) {
      if (src[i] === "{") depth++;
      else if (src[i] === "}") {
        depth--;
        if (depth === 0) break;
      }
      i++;
    }
    const block = src.slice(blockStart, i + 1);

    const prop = (key) => {
      // Match: key: "value" | key: `value` | key: 'value' | key: true/false | key: [...] | key: chalk.yellow("...")
      const strMatch = block.match(new RegExp(`\\b${key}\\s*:\\s*["'\`]([^"'\`]*)["'\`]`));
      if (strMatch) return strMatch[1];
      const boolMatch = block.match(new RegExp(`\\b${key}\\s*:\\s*(true|false)\\b`));
      if (boolMatch) return boolMatch[1] === "true";
      const numMatch = block.match(new RegExp(`\\b${key}\\s*:\\s*(\\d+)\\b`));
      if (numMatch) return parseInt(numMatch[1]);
      // chalk.yellow(...) pattern for deprecated
      if (key === "deprecated") {
        const chalkMatch = block.match(/deprecated\s*:\s*chalk\.[a-z]+\(["'`]([^"'`]*)["'`]\)/);
        if (chalkMatch) return chalkMatch[1];
        // Just presence of deprecated: true is enough
      }
      return undefined;
    };

    // Parse choices array
    const choicesMatch = block.match(/choices\s*:\s*\[([^\]]+)\]/);
    const choices = choicesMatch
      ? choicesMatch[1].match(/["'`]([^"'`]+)["'`]/g)?.map((s) => s.slice(1, -1)) || []
      : undefined;

    // Parse alias (string or array)
    const aliasArrMatch = block.match(/alias\s*:\s*\[([^\]]+)\]/);
    const aliasStrMatch = block.match(/alias\s*:\s*["'`]([^"'`]+)["'`]/);
    const alias = aliasArrMatch
      ? (aliasArrMatch[1].match(/["'`]([^"'`]+)["'`]/g)?.map((s) => s.slice(1, -1)) || [])
      : aliasStrMatch
      ? [aliasStrMatch[1]]
      : undefined;

    const entry = {
      name: optName,
      describe: prop("describe"),
      type: prop("type"),
      alias,
      default: prop("default"),
      choices,
      demandOption: prop("demandOption"),
      deprecated: prop("deprecated"),
      hidden: prop("hidden"),
    };

    if (methodType === "option") options.push(entry);
    else positionals.push(entry);
  }

  return { options, positionals };
}

/** Parse a single command .ts file */
function parseCommandFile(filePath) {
  const src = readFile(filePath);
  if (!src) return null;

  const command = extractStringExport(src, "command");
  const describe = extractStringExport(src, "describe");
  const { options, positionals } = extractBuilderCalls(src);

  return { command, describe, options, positionals, deprecated: isDeprecated(describe) };
}

/** Discover all .ts files in a directory (non-recursive) */
function listCommandFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".ts") && f !== "index.ts" && !f.startsWith("_"))
    .map((f) => path.join(dir, f));
}

// ── Markdown rendering ──────────────────────────────────────────────────────

function renderOption(opt, indent = "") {
  if (opt.hidden) return null; // skip hidden

  const parts = [];
  let flagStr = `--${opt.name}`;
  if (opt.alias?.length) flagStr += `, -${opt.alias[0]}`;
  if (opt.type && opt.type !== "boolean") flagStr += ` <${opt.type}>`;

  let line = `${indent}- \`${flagStr}\``;
  if (opt.describe) line += ` — ${opt.describe}`;
  if (opt.choices) line += ` *(choices: ${opt.choices.join(", ")})*`;
  if (opt.default !== undefined && opt.default !== "" && opt.default !== false)
    line += ` *(default: ${opt.default})*`;
  if (opt.demandOption) line += " *(required)*";
  if (opt.deprecated) line += " **[deprecated]**";

  return line;
}

function renderPositional(pos) {
  const bracket = pos.demandOption ? `<${pos.name}>` : `[${pos.name}]`;
  let line = `- \`${bracket}\``;
  if (pos.describe) line += ` — ${pos.describe}`;
  if (pos.demandOption) line += " *(required)*";
  return line;
}

function renderCommand(info, prefix, level = 4) {
  if (!info || !info.command) return "";
  const heading = "#".repeat(level);
  const fullCmd = `goldsky ${prefix} ${info.command}`.replace(/\s+/g, " ");

  const lines = [`${heading} \`${fullCmd}\``];
  if (info.deprecated) lines.push("\n> **Deprecated**");
  if (info.describe) lines.push(`\n${info.describe}`);

  const visiblePositionals = info.positionals.filter((p) => p.describe || p.name);
  if (visiblePositionals.length) {
    lines.push("\n**Arguments:**");
    visiblePositionals.forEach((p) => lines.push(renderPositional(p)));
  }

  const visibleOptions = info.options
    .map((o) => renderOption(o))
    .filter(Boolean);
  if (visibleOptions.length) {
    lines.push("\n**Options:**");
    visibleOptions.forEach((o) => lines.push(o));
  }

  return lines.join("\n");
}

// ── Turbo (from binary --help) ──────────────────────────────────────────────

function stripBanner(str) {
  return str.replace(/[┌│└][^\n]*/g, "").replace(/\n{3,}/g, "\n\n").trim();
}

function parseTurboHelp(helpText) {
  const clean = stripBanner(helpText);
  const cmds = [];
  const cmdSection = clean.match(/^Commands:([\s\S]*?)^Options:/m);
  if (cmdSection) {
    const lines = cmdSection[1].split("\n").filter((l) => /^\s{2}[a-z]/.test(l));
    lines.forEach((l) => {
      const parts = l.trim().split(/\s{2,}/);
      const name = parts[0].trim();
      const describe = parts.slice(1).join(" ").trim();
      if (name && name !== "help") cmds.push({ name, describe });
    });
  }
  return cmds;
}

function renderTurboSection() {
  const lines = ["## goldsky turbo\n"];
  lines.push("Manages Turbo streaming pipelines. Delegates to the `turbo` binary.\n");

  let topHelp;
  try {
    topHelp = execSync("goldsky turbo --help 2>&1", { encoding: "utf8" });
  } catch (e) {
    lines.push("*Could not run `goldsky turbo --help` — is the CLI installed?*");
    return lines.join("\n");
  }

  const subcommands = parseTurboHelp(topHelp);
  lines.push("### Subcommands\n");

  subcommands.forEach(({ name }) => {
    let cmdHelp;
    try {
      cmdHelp = execSync(`goldsky turbo ${name} --help 2>&1`, { encoding: "utf8" });
    } catch (e) {
      return;
    }
    const clean = stripBanner(cmdHelp);
    const descMatch = clean.match(/^(.+)\n/);
    const desc = descMatch ? descMatch[1].trim() : "";

    const section = [`#### \`goldsky turbo ${name}\`\n`];
    if (desc) section.push(`${desc}\n`);

    // Arguments
    const argsSection = clean.match(/^Arguments:([\s\S]*?)(?=^Options:|^Commands:|$)/m);
    if (argsSection) {
      const argLines = argsSection[1].split("\n").filter((l) => l.trim().startsWith("<") || l.trim().startsWith("["));
      if (argLines.length) {
        section.push("**Arguments:**");
        argLines.forEach((l) => section.push(`- \`${l.trim()}\``));
        section.push("");
      }
    }

    // Options
    const optsSection = clean.match(/^Options:([\s\S]*?)(?=^Commands:|$)/m);
    if (optsSection) {
      const optLines = optsSection[1]
        .split("\n")
        .filter((l) => /^\s{2,}-/.test(l) && !/-h,\s*--help/.test(l))
        .map((l) => `- \`${l.trim()}\``);
      if (optLines.length) {
        section.push("**Options:**");
        optLines.forEach((l) => section.push(l));
        section.push("");
      }
    }

    // Sub-subcommands (e.g. turbo state)
    const subSection = clean.match(/^Commands:([\s\S]*?)(?=^Options:|$)/m);
    if (subSection) {
      const subCmds = subSection[1]
        .split("\n")
        .filter((l) => /^\s{2}[a-z]/.test(l) && !l.includes("help"))
        .map((l) => l.trim().split(/\s{2,}/)[0]);
      if (subCmds.length) {
        section.push(`**Subcommands:** ${subCmds.join(", ")}\n`);
      }
    }

    lines.push(section.join("\n"));
  });

  return lines.join("\n");
}

// ── Command group renderer ──────────────────────────────────────────────────

function renderGroup(verb, dir, level = 2) {
  const indexPath = path.join(dir, "index.ts");
  const indexSrc = readFile(indexPath);
  const groupDescribe = indexSrc ? extractStringExport(indexSrc, "describe") : null;

  const lines = [`${"#".repeat(level)} goldsky ${verb}\n`];
  if (groupDescribe) lines.push(`${groupDescribe}\n`);

  // Find all immediate subcommand files
  const cmdFiles = listCommandFiles(dir);

  // Find nested subdirectories (e.g. snapshots/, tag/, users/)
  const subdirs = fs.existsSync(dir)
    ? fs
        .readdirSync(dir)
        .filter((f) => {
          const full = path.join(dir, f);
          return fs.statSync(full).isDirectory();
        })
        .map((f) => ({ name: f, full: path.join(dir, f) }))
    : [];

  // Render flat commands
  const cmds = cmdFiles
    .map((f) => parseCommandFile(f))
    .filter((c) => c && c.command);

  if (cmds.length || subdirs.length) {
    lines.push(`### Subcommands\n`);
  }

  cmds.forEach((cmd) => {
    lines.push(renderCommand(cmd, verb, level + 2));
    lines.push("");
  });

  // Render nested groups
  subdirs.forEach(({ name, full }) => {
    const subIndexSrc = readFile(path.join(full, "index.ts"));
    if (!subIndexSrc) return;
    const subDescribe = extractStringExport(subIndexSrc, "describe");

    lines.push(`${"#".repeat(level + 2)} \`goldsky ${verb} ${name}\``);
    if (subDescribe) lines.push(`\n${subDescribe}`);
    lines.push("");

    const subFiles = listCommandFiles(full);
    subFiles.forEach((f) => {
      const cmd = parseCommandFile(f);
      if (cmd && cmd.command) {
        lines.push(renderCommand(cmd, `${verb} ${name}`, level + 3));
        lines.push("");
      }
    });
  });

  return lines.join("\n");
}

// ── Main ────────────────────────────────────────────────────────────────────

function main() {
  let turboVersion = "unknown";
  try {
    turboVersion = execSync("goldsky turbo --version 2>/dev/null", { encoding: "utf8" }).trim();
  } catch (_) {}

  const sections = [];

  // Frontmatter
  sections.push(`---
name: cli-reference
description: "Goldsky CLI command and flag reference — all valid subcommands, arguments, and options for goldsky turbo, pipeline, subgraph, secret, project, dataset, indexed, and telemetry. Consult before suggesting any goldsky command to avoid hallucinating invalid commands or flags."
---

# Goldsky CLI Reference

> Auto-generated from the Goldsky CLI source and turbo binary (${turboVersion}).
> Re-run \`node scripts/generate-cli-reference.js\` to update.
`);

  // Top-level commands (login/logout are simple, no options worth documenting)
  sections.push(`## goldsky login / logout

- \`goldsky login\` — Authenticate with Goldsky
- \`goldsky logout\` — Remove stored credentials
`);

  // turbo (from binary)
  sections.push(renderTurboSection());

  // TypeScript CLI command groups
  const groups = ["pipeline", "subgraph", "secret", "project", "dataset", "indexed", "telemetry"];
  groups.forEach((verb) => {
    const dir = path.join(COMMANDS_DIR, verb);
    if (!fs.existsSync(dir)) return;
    sections.push(renderGroup(verb, dir));
  });

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, sections.join("\n---\n\n"));
  console.log(`Generated: ${OUTPUT}`);
}

main();
