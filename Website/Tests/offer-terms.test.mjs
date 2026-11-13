import test from 'node:test';
import assert from 'node:assert/strict';
import { initialiseOfferTerms } from '../Assets/offer-terms.mjs';

function fixture() {
  const nodes = new Map();
  const cards = ['offer-terms-61', 'offer-terms-62'].map(id => {
    const title = { id: `${id}-title` };
    const fallback = { hidden: false };
    const trigger = { hidden: true };
    nodes.set(title.id, title);
    nodes.set(`${id}-fallback`, fallback);
    const attributes = new Map([['aria-labelledby', 'modalLabel']]);
    const card = { querySelector: selector => selector === '[data-offer-terms-trigger]' ? trigger : null };
    const modal = {
      id,
      closest: selector => selector === '.product-card' ? card : null,
      setAttribute: (name, value) => attributes.set(name, value)
    };
    return { title, fallback, trigger, modal, attributes };
  });
  const root = {
    querySelectorAll: selector => selector === '.modal[id^="offer-terms-"]' ? cards.map(card => card.modal) : [],
    getElementById: id => nodes.get(id)
  };
  return { cards, nodes, root };
}

test('terms stay available through native details without the dialog library', () => {
  const { cards, root } = fixture();
  initialiseOfferTerms(root, false);
  for (const card of cards) {
    assert.equal(card.fallback.hidden, false);
    assert.equal(card.trigger.hidden, true);
  }
});

test('each enhanced dialog uses its own heading and replaces only its own fallback', () => {
  const { cards, root } = fixture();
  initialiseOfferTerms(root, true);
  for (const card of cards) {
    assert.equal(card.attributes.get('aria-labelledby'), card.title.id);
    assert.equal(card.fallback.hidden, true);
    assert.equal(card.trigger.hidden, false);
  }
});

test('an incomplete dialog retains readable terms while other cards still enhance', () => {
  const { cards, nodes, root } = fixture();
  nodes.delete(cards[0].title.id);
  initialiseOfferTerms(root, true);
  assert.equal(cards[0].fallback.hidden, false);
  assert.equal(cards[0].trigger.hidden, true);
  assert.equal(cards[1].fallback.hidden, true);
  assert.equal(cards[1].trigger.hidden, false);
});
