import { readFileSync, readdirSync } from 'node:fs';
import { resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseDocument } from 'yaml';

export function validateSkill(source, directoryName) {
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if (!match) throw new Error('Missing or unclosed YAML frontmatter');
  const document = parseDocument(match[1]);
  if (document.errors.length) throw new Error(document.errors.map(error => error.message).join('; '));
  const metadata = document.toJS();
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    throw new Error('Frontmatter must be a mapping');
  }
  const { name, description } = metadata;
  if (typeof name !== 'string' || name.length > 64 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
    throw new Error('Name must be 1–64 lowercase letters, digits, or single hyphens between words');
  }
  if (name !== directoryName) throw new Error(`Name must match directory: ${directoryName}`);
  if (typeof description !== 'string' || !description.trim() || [...description].length > 1024) {
    throw new Error('Description must be a non-empty string of at most 1024 characters');
  }
  return metadata;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const root = resolve(process.argv[2] || 'skills');
  let count = 0;
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const file = resolve(root, entry.name, 'SKILL.md');
    try {
      validateSkill(readFileSync(file, 'utf8'), basename(resolve(root, entry.name)));
      count++;
    } catch (error) {
      console.error(`${file}: ${error.message}`);
      process.exitCode = 1;
    }
  }
  if (!process.exitCode) console.log(`Validated name and description metadata for ${count} skills.`);
}
