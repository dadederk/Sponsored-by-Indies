export function initialiseOfferTerms(root, dialogsAvailable) {
  if (!dialogsAvailable) return;
  for (const modal of root.querySelectorAll('.modal[id^="offer-terms-"]')) {
    const title = root.getElementById(`${modal.id}-title`);
    const fallback = root.getElementById(`${modal.id}-fallback`);
    const trigger = modal.closest('.product-card')?.querySelector('[data-offer-terms-trigger]');
    if (!title || !fallback || !trigger) continue;
    // Ignite 0.7.2 ignores Modal's attributes and hard-codes "modalLabel".
    modal.setAttribute('aria-labelledby', title.id);
    fallback.hidden = true;
    trigger.hidden = false;
  }
}

// Native details stay usable if either script fails to load.
if (typeof document !== 'undefined') initialiseOfferTerms(document, Boolean(globalThis.bootstrap?.Modal));
