import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const website = new URL('../', import.meta.url);
const read = path => readFile(new URL(path, website), 'utf8');
const references = value => [...value.matchAll(/var\((--[\w-]+)/g)].map(match => match[1]);
const conferenceVariables = new Set(['--conference-bg', '--conference-accent', '--conference-highlight', '--conference-detail']);

for (const directory of ['Build', 'BuildPublic']) {
  test(`${directory}: shared CSS variables resolve without cycles`, async () => {
    const tokens = await read(`${directory}/design-tokens.css`);
    const styles = await read(`${directory}/styles.css`);
    const values = new Map([...tokens.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)].map(match => [match[1], match[2]]));
    const definitions = new Set([...values.keys(), ...[...styles.matchAll(/(--[\w-]+)\s*:/g)].map(match => match[1])]);
    for (const name of references(tokens + styles)) {
      assert.ok(definitions.has(name) || conferenceVariables.has(name), `Undefined variable: ${name}`);
    }
    function visit(name, path = []) {
      assert.ok(!path.includes(name), `Circular design token: ${[...path, name].join(' → ')}`);
      for (const dependency of references(values.get(name) ?? '')) visit(dependency, [...path, name]);
    }
    for (const name of values.keys()) visit(name);
    assert.doesNotMatch(styles, /#[\da-f]{6}\b/i, 'Site palette values belong in DesignTokens.swift.');
  });

  test(`${directory}: generated artwork resolves colours and preserves geometry`, async () => {
    for (const name of ['logo.svg', 'logo-inverse.svg', 'favicon.svg', 'favicon-shared-imprint-01.svg']) {
      const source = await read(`Assets/${name}`);
      const output = await read(`${directory}/${name}`);
      assert.ok(source.includes('var(--'), `${name}: source has palette bindings`);
      assert.ok(!output.includes('var(--'), `${name}: no dependence on page CSS inheritance`);
      const geometry = svg => [...svg.matchAll(/\b(?:d|viewBox|cx|cy|r|rx|ry|width|height)="[^"]*"/g)].map(match => match[0]);
      assert.deepEqual(geometry(output), geometry(source), `${name}: preserve selected artwork`);
    }
  });
}
