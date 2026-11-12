import assert from 'node:assert/strict';

// Generated attributes use double quotes. Require whitespace before the name so
// data-id and aria-labelledby are not mistaken for an element's id attribute.
export const attributes = (html, name) => [...html.matchAll(new RegExp(`\\s${name}="([^"]*)"`, 'g'))]
  .map(match => match[1]);

export function assertCanonicalURL(html, expected, label) {
  const canonicals = [...html.matchAll(/<link\b[^>]*>/g)]
    .map(match => match[0])
    .filter(link => attributes(link, 'rel').some(value => value.split(/\s+/).includes('canonical')));
  assert.equal(canonicals.length, 1, `${label}: exactly one canonical link`);
  assert.equal(attributes(canonicals[0], 'href')[0], expected, `${label}: canonical URL`);
}
