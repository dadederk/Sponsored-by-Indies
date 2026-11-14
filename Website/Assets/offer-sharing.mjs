export function initialiseOfferSharing(root, pageURL, clipboard = globalThis.navigator?.clipboard) {
  // A normal permalink remains available without JavaScript or clipboard support.
  if (!clipboard?.writeText) return;
  const base = root.querySelector('link[rel="canonical"]')?.href || pageURL;
  for (const sharing of root.querySelectorAll('[data-offer-sharing]')) {
    const link = sharing.querySelector('[data-offer-permalink]');
    const button = sharing.querySelector('[data-offer-copy]');
    const status = sharing.querySelector('[data-offer-copy-status]');
    const fallback = sharing.querySelector('[data-offer-copy-fallback]');
    const field = fallback?.querySelector('input');
    if (!link || !button || !status || !fallback || !field) continue;
    const copyIcon = button.querySelector('[data-copy-icon]');
    const copiedIcon = button.querySelector('[data-copied-icon]');
    const url = new URL(link.getAttribute('href'), base).href;
    let copying = false;
    button.addEventListener('click', async () => {
      if (copying) return;
      copying = true;
      status.textContent = '';
      fallback.hidden = true;
      if (copyIcon) copyIcon.hidden = false;
      if (copiedIcon) copiedIcon.hidden = true;
      try {
        await clipboard.writeText(url);
        if (copyIcon) copyIcon.hidden = true;
        if (copiedIcon) copiedIcon.hidden = false;
        status.textContent = ' Link copied.';
      } catch {
        status.textContent = ' Copy the link below.';
        field.value = url;
        fallback.hidden = false;
        field.focus();
        field.select();
      } finally {
        copying = false;
      }
    });
    link.hidden = true;
    button.hidden = false;
  }
}

if (typeof document !== 'undefined') initialiseOfferSharing(document, location.href);
