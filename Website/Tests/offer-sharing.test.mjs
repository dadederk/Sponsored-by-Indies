import test from 'node:test';
import assert from 'node:assert/strict';
import { initialiseOfferSharing } from '../Assets/offer-sharing.mjs';

function fixture(canonical = 'https://sponsored.example/conferences/north/') {
  const cards = ['first', 'second'].map(id => {
    const listeners = {};
    const link = { hidden: false, getAttribute: () => `/conferences/north/2027/#project-${id}` };
    const copyIcon = { hidden: false };
    const copiedIcon = { hidden: true };
    const button = { hidden: true, addEventListener: (type, listener) => { listeners[type] = listener; },
      querySelector: selector => selector === '[data-copy-icon]' ? copyIcon : copiedIcon };
    const status = { textContent: '' };
    const field = { value: '', focus() { this.focused = true; }, select() { this.selected = true; } };
    const fallback = { hidden: true, querySelector: () => field };
    const nodes = { '[data-offer-permalink]': link, '[data-offer-copy]': button,
      '[data-offer-copy-status]': status, '[data-offer-copy-fallback]': fallback };
    return { link, button, status, field, fallback, copyIcon, copiedIcon, listeners, querySelector: selector => nodes[selector] };
  });
  const root = { querySelector: () => canonical ? { href: canonical } : null, querySelectorAll: () => cards };
  return { cards, root };
}

test('copying uses the canonical host, fixed edition and the selected project, without page queries', async () => {
  const { cards, root } = fixture();
  const copied = [];
  initialiseOfferSharing(root, 'http://localhost:8000/conferences/north/?tracking=yes#bundle', {
    writeText: async value => copied.push(value)
  });
  for (const card of cards) {
    assert.equal(card.link.hidden, true);
    assert.equal(card.button.hidden, false);
    await card.listeners.click();
    assert.match(card.status.textContent, /Link copied/);
    assert.equal(card.fallback.hidden, true);
    assert.equal(card.copyIcon.hidden, true);
    assert.equal(card.copiedIcon.hidden, false);
  }
  assert.deepEqual(copied, ['https://sponsored.example/conferences/north/2027/#project-first',
    'https://sponsored.example/conferences/north/2027/#project-second']);
});

test('missing clipboard support keeps native permalinks usable', () => {
  const { cards, root } = fixture();
  initialiseOfferSharing(root, 'https://example.org/', {});
  for (const card of cards) {
    assert.equal(card.link.hidden, false);
    assert.equal(card.button.hidden, true);
  }
});

test('a rejected copy offers the full selected link for manual copying and allows a retry', async () => {
  const { cards, root } = fixture(null);
  let attempts = 0;
  initialiseOfferSharing(root, 'http://localhost:8000/conferences/north/', {
    writeText: async () => { if (++attempts === 1) throw new Error('Denied'); }
  });
  const card = cards[1];
  await card.listeners.click();
  assert.equal(card.field.value, 'http://localhost:8000/conferences/north/2027/#project-second');
  assert.equal(card.field.focused, true);
  assert.equal(card.field.selected, true);
  assert.equal(card.fallback.hidden, false);
  assert.match(card.status.textContent, /Copy the link below/);
  assert.equal(card.copyIcon.hidden, false);
  assert.equal(card.copiedIcon.hidden, true);
  assert.equal(cards[0].fallback.hidden, true);
  await card.listeners.click();
  assert.equal(card.fallback.hidden, true);
  assert.match(card.status.textContent, /Link copied/);
});

test('repeated activation does not start overlapping clipboard requests', async () => {
  const { cards, root } = fixture();
  let finish;
  let calls = 0;
  initialiseOfferSharing(root, 'https://example.org/', { writeText: () => {
    calls++;
    return new Promise(resolve => { finish = resolve; });
  } });
  const pending = cards[0].listeners.click();
  await cards[0].listeners.click();
  assert.equal(calls, 1);
  finish();
  await pending;
  assert.match(cards[0].status.textContent, /Link copied/);
});
