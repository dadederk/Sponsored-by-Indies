// Compare normalized Unicode scalar values, matching Swift String ordering.
// Locale collation can otherwise change the build's same-day edition choice.
function compareText(left, right) {
  const a = Array.from(left.normalize("NFC"), character => character.codePointAt(0));
  const b = Array.from(right.normalize("NFC"), character => character.codePointAt(0));
  for (let index = 0; index < Math.min(a.length, b.length); index++) {
    if (a[index] !== b[index]) return a[index] - b[index];
  }
  return a.length - b.length;
}

// ISO date-only strings sort chronologically. Match the build's UTC calendar day.
export function nextEdition(editions, today = new Date().toISOString().slice(0, 10)) {
  return editions.filter(edition => edition.endDate >= today)
    .sort((a, b) => compareText(a.startDate, b.startDate) || compareText(a.id, b.id))[0];
}

if (typeof document !== "undefined") {
  const section = document.getElementById("next-edition");
  if (section) {
    const cards = [...section.querySelectorAll("[data-next-edition]")];
    const editions = cards.map(card => ({
      id: card.dataset.nextEdition,
      startDate: card.dataset.startDate,
      endDate: card.dataset.endDate
    }));
    function refresh() {
      const featured = nextEdition(editions);
      cards.forEach(card => { card.hidden = card.dataset.nextEdition !== featured?.id; });
      document.getElementById("next-edition-empty").hidden = Boolean(featured);
    }
    refresh();
    // Re-evaluate when returning to a page restored from browser history.
    window.addEventListener("pageshow", refresh);
  }
}
