import test from 'node:test';
import assert from 'node:assert/strict';
import { createEmailDraftController, makeEmailDraft } from '../Assets/email-draft.mjs';

function fixture(t, writeText) {
  const nodes = new Map();
  const document = { getElementById: id => {
    if (!nodes.has(id)) nodes.set(id, {
      hidden: true, textContent: '', value: '', focuses: 0, selections: 0, listeners: {},
      classList: { toggle() {} },
      focus() { this.focuses++; },
      select() { this.selections++; },
      removeAttribute(name) { delete this[name]; },
      addEventListener(name, listener) { this.listeners[name] = listener; }
    });
    return nodes.get(id);
  } };
  for (const [name, value] of Object.entries({ document, navigator: { clipboard: { writeText } } })) {
    const previous = Object.getOwnPropertyDescriptor(globalThis, name);
    Object.defineProperty(globalThis, name, { configurable: true, value });
    t.after(() => previous ? Object.defineProperty(globalThis, name, previous) : delete globalThis[name]);
  }
  const form = new EventTarget();
  form.dataset = { recipient: 'hello@example.org' };
  const controller = createEmailDraftController(form);
  t.after(() => controller.invalidate());
  const show = body => controller.show(makeEmailDraft('An enquiry', body, form.dataset.recipient), { previewOnly: true });
  return { form, show, get: document.getElementById };
}

for (const outcome of ['success', 'failure']) {
  test(`a clipboard ${outcome} for the current draft still gives the appropriate feedback`, async t => {
    let copied;
    const { show, get } = fixture(t, async text => {
      copied = text;
      if (outcome === 'failure') throw new Error('Copying unavailable');
    });
    show('The current proposal');
    await get('copy-draft').listeners.click();
    assert.equal(copied, 'The current proposal');
    assert.match(get('form-status').textContent, outcome === 'success' ? /Email text copied/ : /Automatic copying is unavailable/);
    assert.equal(get('draft-body').selections, outcome === 'success' ? 0 : 1);
  });

  test(`a delayed clipboard ${outcome} cannot replace feedback or focus after answers change`, async t => {
    let finish;
    const { form, show, get } = fixture(t, () => new Promise((resolve, reject) => {
      finish = outcome === 'success' ? resolve : () => reject(new Error('Copying unavailable'));
    }));
    show('The original proposal');
    const copying = get('copy-draft').listeners.click();
    form.dispatchEvent(new Event('input'));
    const feedback = get('form-status').textContent;
    const focuses = get('draft-body').focuses;
    finish();
    await copying;
    assert.equal(get('draft-preview').hidden, true);
    assert.equal(get('form-status').textContent, feedback);
    assert.equal(get('draft-body').focuses, focuses);
    assert.equal(get('draft-body').selections, 0);
  });
}

test('a clipboard result for a previous draft cannot overwrite a newly prepared preview', async t => {
  let finish;
  const { show, get } = fixture(t, () => new Promise(resolve => { finish = resolve; }));
  show('The original proposal');
  const copying = get('copy-draft').listeners.click();
  show('The updated proposal');
  const feedback = get('form-status').textContent;
  finish();
  await copying;
  assert.equal(get('draft-body').value, 'The updated proposal');
  assert.equal(get('form-status').textContent, feedback);
});
