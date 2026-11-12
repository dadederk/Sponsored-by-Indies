import test from 'node:test';
import assert from 'node:assert/strict';
import { attributes, assertCanonicalURL } from './Support/output-checks.mjs';

const expected = 'https://chosen.example/conferences/sample/2027/';

test('canonical checks accept either attribute order and a chosen deployment domain', () => {
  assertCanonicalURL(`<link rel="canonical" href="${expected}">`, expected, 'fixture');
  assertCanonicalURL(`<link href="${expected}" rel="canonical">`, expected, 'fixture');
});

test('canonical checks reject the wrong page, host and duplicate declarations', () => {
  for (const href of ['https://chosen.example/', 'https://chosenXexample/conferences/sample/2027/']) {
    assert.throws(() => assertCanonicalURL(`<link rel="canonical" href="${href}">`, expected, 'fixture'));
  }
  const link = `<link rel="canonical" href="${expected}">`;
  assert.throws(() => assertCanonicalURL(link + link, expected, 'fixture'));
  assert.throws(() => assertCanonicalURL('', expected, 'fixture'));
});

test('element IDs exclude data attributes with a similar name', () => {
  assert.deepEqual(attributes('<section data-id="tracking" id="main">', 'id'), ['main']);
});
