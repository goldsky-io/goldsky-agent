import assert from 'node:assert/strict';
import test from 'node:test';
import { validateSkill } from '../scripts/validate-skills.mjs';

const skill = description => `---\nname: example\ndescription: ${description}\n---\nBody\n`;

test('validates decoded YAML values, including folded and quoted descriptions', () => {
  assert.equal(validateSkill(skill('>\n  First line\n  second line'), 'example').description, 'First line second line\n');
  assert.equal(validateSkill(skill('"A \\"quoted\\" description"'), 'example').name, 'example');
});

test('accepts 1024 Unicode characters and rejects 1025', () => {
  validateSkill(skill(JSON.stringify('🟡'.repeat(1024))), 'example');
  assert.throws(() => validateSkill(skill(JSON.stringify('a'.repeat(1025))), 'example'), /1024/);
});

test('rejects malformed YAML, duplicate fields, missing fields, and non-string descriptions', () => {
  for (const source of [skill('[unclosed'), skill('true'), skill('42'), skill('null'), skill('"   "'),
    '---\nname: example\n---\n', skill('ok\ndescription: again'), 'name: example\n',
    '---\n- example\n---\n']) {
    assert.throws(() => validateSkill(source, 'example'));
  }
});

test('rejects invalid names and mismatched directories', () => {
  for (const name of ['-example', 'example-', 'Example', 'example--skill', 'a'.repeat(65)]) {
    assert.throws(() => validateSkill(skill('ok').replace('name: example', `name: ${name}`), name), /Name/);
  }
  assert.throws(() => validateSkill(skill('ok'), 'another'), /directory/);
});
