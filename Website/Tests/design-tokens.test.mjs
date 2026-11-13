import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

const website = new URL('../', import.meta.url);
const read = path => readFile(new URL(path, website), 'utf8');
const references = value => [...value.matchAll(/var\((--[\w-]+)/g)].map(match => match[1]);
const conferenceVariables = new Set(['--conference-bg', '--conference-accent', '--conference-highlight', '--conference-detail']);

test('published text colours retain contrast across shared and conference themes', async () => {
  const tokens = await read('BuildPublic/design-tokens.css');
  const colours = new Map([...tokens.matchAll(/--([\w-]+)\s*:\s*(#[\da-f]{6});/gi)].map(match => [match[1], match[2]]));
  function luminance(hex) {
    assert.match(hex, /^#[\da-f]{6}$/i);
    const channels = hex.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
      .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
    return channels.reduce((total, value, index) => total + value * [0.2126, 0.7152, 0.0722][index], 0);
  }
  function check(label, foreground, background) {
    const [dark, light] = [luminance(foreground), luminance(background)].sort((a, b) => a - b);
    const ratio = (light + 0.05) / (dark + 0.05);
    assert.ok(ratio >= 4.5, `${label}: text contrast ${ratio.toFixed(2)}:1 is below 4.5:1`);
  }
  for (const [foreground, background] of [
    ['ink', 'paper'], ['muted', 'paper'], ['muted', 'surface'],
    ['blue', 'tint'], ['accent', 'paper'], ['white', 'accent'], ['white', 'accent-hover']
  ]) check(`${foreground} on ${background}`, colours.get(foreground), colours.get(background));
  for (const file of await readdir(new URL('Data/Conferences/', website))) {
    if (!file.endsWith('.json')) continue;
    const { conference } = JSON.parse(await read(`Data/Conferences/${file}`));
    const branding = conference.branding;
    const background = branding?.background ?? colours.get('ink');
    for (const [role, foreground] of [
      ['body', colours.get('white')],
      ['accent', branding?.accent ?? colours.get('accent-soft')],
      ['detail', branding?.detail ?? colours.get('accent-soft')],
      ['button', branding?.highlight ?? colours.get('accent-soft')]
    ]) check(`${conference.name} ${role}`, foreground, background);
  }
});

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
