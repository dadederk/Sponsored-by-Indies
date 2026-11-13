const newline = "\r\n";
// An advisory only: email apps have different URL limits. Always offer the full link.
export const LONG_EMAIL_HINT_LENGTH = 1900;

export function makeContributionEmail(data, recipient) {
  const clean = value => String(value ?? "").trim();
  const line = (label, value) => clean(value) ? `${label}: ${clean(value)}` : null;
  const subject = Array.from(`Indie contribution — ${clean(data.conference)} — ${clean(data.name)}`.replace(/[\r\n]+/g, " ")).slice(0, 100).join("");
  const lines = [
    "Hi! I’d like to contribute to Sponsored by Indies.", "",
    "ABOUT ME", line("Name", data.name), line("Contact email", data.email),
    line("Company/team", data.company), line("Website", data.website),
    line("Social links", data.socials), line("Photo/avatar/press kit", data.assets), "",
    "CONFERENCE CONNECTION", line("Conference and edition", data.conference),
    line("My connection", data.connection), line("Conference quote", data.quote), ""
  ];
  data.resources.forEach((resource, index) => {
    lines.push(`RESOURCE ${index + 1}`, line("Name", resource.product), line("URL", resource.url),
      line("Type", resource.category), line("Description", resource.description), "");
    resource.offers.forEach((offer, offerIndex) => {
      lines.push(`Offer ${offerIndex + 1}`, line("Offer type", offer.kind),
        line("Attendee price/discount", offer.kind === "Free" ? "Free (0)" : offer.discount),
        line("Available to", offer.audience));
      if (offer.audience === "Limited prize licenses") lines.push(line("Prize licenses", offer.quantity));
      lines.push(line("Product edition/plan", offer.plan), line("Usual price and currency", offer.regularPrice),
        line("Access duration", offer.duration), line("Last day to claim", offer.validUntil),
        line("Conditions and redemption", offer.conditions), "");
    });
  });
  lines.push("This is an initial proposal. Final offers and public profile details are still to be agreed.");
  const body = lines.filter(line => line !== null).join(newline).replace(/\r\n|\r|\n/g, newline);
  const address = encodeURIComponent(recipient).replace(/%40/g, "@");
  const mailto = `mailto:${address}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  return { subject, body, mailto, isLong: mailto.length > LONG_EMAIL_HINT_LENGTH };
}

function base64(text) {
  return btoa(Array.from(new TextEncoder().encode(text), byte => String.fromCharCode(byte)).join(""));
}

// MIME encoding keeps Unicode, long answers and header-like body text intact.
export function makeEmailFile(draft, recipient) {
  if (/[\r\n<>]/.test(recipient)) throw new Error("Invalid email recipient");
  const subject = Array.from(draft.subject.matchAll(/.{1,10}/gu), match => `=?UTF-8?B?${base64(match[0])}?=`).join(`${newline} `);
  const body = base64(draft.body).match(/.{1,76}/g)?.join(newline) ?? "";
  return ["X-Unsent: 1", `To: ${recipient}`, `Subject: ${subject}`, "MIME-Version: 1.0",
    'Content-Type: text/plain; charset="UTF-8"', "Content-Transfer-Encoding: base64", "", body, ""].join(newline);
}

function initialiseForm() {
  const form = document.getElementById("contribution-form");
  if (!form) return;
  const status = document.getElementById("form-status");
  const preview = document.getElementById("draft-preview");
  const bodyField = document.getElementById("draft-body");
  const subjectField = document.getElementById("draft-subject");
  const emailLink = document.getElementById("draft-email-link");
  const downloadLink = document.getElementById("download-draft");
  const addButton = document.getElementById("add-resource");
  const resourceTemplate = form.querySelector("[data-resource]").cloneNode(true);
  const offerTemplate = resourceTemplate.querySelector("[data-offer]").cloneNode(true);
  let resourceID = 1;
  let offerID = 1;
  let currentDraft;
  let downloadURL;

  function invalidateDraft() {
    if (!currentDraft) return;
    currentDraft = undefined;
    preview.hidden = true;
    if (downloadURL) URL.revokeObjectURL(downloadURL);
    downloadURL = undefined;
    downloadLink.removeAttribute("href");
    emailLink.removeAttribute("href");
    status.textContent = "Your answers changed. Prepare a new draft to include the changes.";
  }
  form.addEventListener("input", invalidateDraft);
  form.addEventListener("invalid", event => {
    // Optional details may have been collapsed after entering an invalid date.
    let details = event.target.closest("details");
    while (details) {
      details.open = true;
      details = details.parentElement.closest("details");
    }
  }, true);
  form.addEventListener("change", event => {
    invalidateDraft();
    const offer = event.target.closest("[data-offer]");
    if (offer) updateOffer(offer);
  });

  const resources = () => [...form.querySelectorAll("fieldset[data-resource]")];
  const offers = resource => [...resource.querySelectorAll("fieldset[data-offer]")];
  function updateOffer(offer) {
    const free = offer.querySelector('[data-resource-field="kind"]').value === "Free";
    const discount = offer.querySelector("[data-discount-details]");
    discount.hidden = free;
    discount.querySelector("input").disabled = free;
    discount.querySelector("input").required = !free;
    const prize = offer.querySelector('[data-resource-field="audience"]').value === "Limited prize licenses";
    const quantity = offer.querySelector("[data-prize-details]");
    quantity.hidden = !prize;
    quantity.querySelector("input").disabled = !prize;
    quantity.querySelector("input").required = prize;
  }

  function renumberResources() {
    const fields = resources();
    fields.forEach((fieldset, index) => {
      fieldset.querySelector("legend").textContent = `Resource ${index + 1}`;
      const button = fieldset.querySelector("[data-remove-resource]");
      button.querySelector("[data-action-label]").textContent = `Remove resource ${index + 1}`;
      button.hidden = fields.length === 1;
      fieldset.querySelector("[data-add-offer]").setAttribute("aria-label", `Add another offer to resource ${index + 1}`);
      const entries = offers(fieldset);
      entries.forEach((offer, offerIndex) => {
        offer.querySelector("legend").textContent = `Offer ${offerIndex + 1}`;
        const remove = offer.querySelector("[data-remove-offer]");
        remove.querySelector("[data-action-label]").textContent = `Remove offer ${offerIndex + 1}`;
        remove.setAttribute("aria-label", `Remove offer ${offerIndex + 1} from resource ${index + 1}`);
        remove.hidden = entries.length === 1;
      });
    });
  }

  function cloneFields(template, prefix) {
    const clone = template.cloneNode(true);
    const oldPrefix = template.id;
    clone.id = prefix;
    clone.querySelectorAll("[id],[name],[for],[aria-describedby],[aria-labelledby]").forEach(element => {
      for (const attribute of ["id", "name", "for", "aria-describedby", "aria-labelledby"]) {
        const value = element.getAttribute(attribute);
        if (value) element.setAttribute(attribute, value.split(/\s+/).map(token =>
          token.startsWith(`${oldPrefix}-`) ? prefix + token.slice(oldPrefix.length) : token).join(" "));
      }
    });
    return clone;
  }

  addButton.addEventListener("click", () => {
    invalidateDraft();
    const clone = cloneFields(resourceTemplate, `resource-${++resourceID}`);
    resources().at(-1).after(clone);
    offers(clone).forEach(updateOffer);
    renumberResources();
    clone.querySelector("input").focus();
    status.textContent = `Resource ${resources().length} added.`;
  });

  form.addEventListener("click", event => {
    const addOffer = event.target.closest("[data-add-offer]");
    if (addOffer) {
      invalidateDraft();
      const resource = addOffer.closest("[data-resource]");
      const clone = cloneFields(offerTemplate, `${resource.id}-offer-${++offerID}`);
      offers(resource).at(-1).after(clone);
      updateOffer(clone);
      renumberResources();
      clone.querySelector("select").focus();
      status.textContent = `Offer ${offers(resource).length} added to resource ${resources().indexOf(resource) + 1}.`;
      return;
    }
    const removeOffer = event.target.closest("[data-remove-offer]");
    if (removeOffer) {
      const resource = removeOffer.closest("[data-resource]");
      if (offers(resource).length === 1) return;
      invalidateDraft();
      const offer = removeOffer.closest("[data-offer]");
      const offerNumber = offers(resource).indexOf(offer) + 1;
      const resourceNumber = resources().indexOf(resource) + 1;
      offer.remove();
      renumberResources();
      resource.querySelector("[data-add-offer]").focus();
      const remaining = offers(resource).length;
      status.textContent = `Offer ${offerNumber} removed from resource ${resourceNumber}. ${remaining} ${remaining === 1 ? "offer remains" : "offers remain"}.`;
      return;
    }
    const remove = event.target.closest("[data-remove-resource]");
    if (!remove || resources().length === 1) return;
    invalidateDraft();
    const resource = remove.closest("fieldset[data-resource]");
    const resourceNumber = resources().indexOf(resource) + 1;
    resource.remove();
    renumberResources();
    addButton.focus();
    const remaining = resources().length;
    status.textContent = `Resource ${resourceNumber} removed. ${remaining} ${remaining === 1 ? "resource remains" : "resources remain"}.`;
  });

  function readFields(container, offerFields) {
    return Object.fromEntries([...container.querySelectorAll("[data-resource-field]")]
      .filter(control => !control.disabled && Boolean(control.closest("[data-offer]")) === offerFields)
      .map(control => [control.dataset.resourceField, control.value]));
  }

  function readForm() {
    const value = name => form.elements.namedItem(name)?.value ?? "";
    return {
      name: value("maker-name"), email: value("maker-email"), company: value("maker-company"),
      website: value("maker-website"), socials: value("maker-socials"), assets: value("maker-assets"),
      conference: value("conference"), connection: value("connection"), quote: value("conference-quote"),
      resources: resources().map(resource => ({ ...readFields(resource, false),
        offers: offers(resource).map(offer => readFields(offer, true)) }))
    };
  }

  form.addEventListener("submit", event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    if (downloadURL) URL.revokeObjectURL(downloadURL);
    currentDraft = makeContributionEmail(readForm(), form.dataset.recipient);
    subjectField.value = currentDraft.subject;
    bodyField.value = currentDraft.body;
    emailLink.href = currentDraft.mailto;
    downloadURL = URL.createObjectURL(new Blob([makeEmailFile(currentDraft, form.dataset.recipient)], { type: "message/rfc822" }));
    downloadLink.href = downloadURL;
    preview.hidden = false;
    const longHint = currentDraft.isLong ? " If your app cannot open this long draft, download the complete email file below or use Copy email text." : "";
    if (event.submitter?.value === "preview") {
      status.textContent = `Your email preview is ready. Nothing has been sent.${longHint}`;
      bodyField.focus();
    } else {
      status.textContent = `Opening your email app with the recipient, subject and complete text. Nothing has been sent by this website.${longHint}`;
      window.location.assign(currentDraft.mailto);
    }
  });

  document.getElementById("copy-draft").addEventListener("click", async () => {
    if (!currentDraft) return;
    try {
      await navigator.clipboard.writeText(currentDraft.body);
      status.textContent = "Email text copied. Open your email draft, paste the text if needed, then review and send it.";
    } catch {
      bodyField.focus();
      bodyField.select();
      status.textContent = "Automatic copying is unavailable. The email text is selected; copy it, then paste it into your email draft.";
    }
  });

  offers(resources()[0]).forEach(updateOffer);
  renumberResources();
  form.hidden = false;
}

if (typeof document !== "undefined") initialiseForm();
