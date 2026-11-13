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
    lines.push(`CONTRIBUTION ${index + 1}`, line("Name", resource.product), line("URL", resource.url),
      line("Description", resource.description), "");
    resource.offers.forEach((offer, offerIndex) => {
      lines.push(`${offerIndex + 1}. Offer`, clean(offer.proposal), "");
    });
  });
  lines.push("This is an initial proposal. Final offers and public profile details are still to be agreed.");
  const body = lines.filter(line => line !== null).join(newline).replace(/\r\n|\r|\n/g, newline);
  const address = encodeURIComponent(recipient).replace(/%40/g, "@");
  const mailto = `mailto:${address}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  return { subject, body, mailto, isLong: mailto.length > LONG_EMAIL_HINT_LENGTH };
}

function encodeBytes(bytes) {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 8192) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
  }
  return btoa(binary);
}

function base64(text) {
  return encodeBytes(new TextEncoder().encode(text));
}

const imageExtensions = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp" };
export function validateIcons(files) {
  if (files.some(file => !imageExtensions[file.type])) return "Choose a PNG, JPEG or WebP image.";
  if (files.some(file => file.size > 5 * 1024 * 1024)) return "Each image must be 5 MB or smaller.";
  if (files.reduce((total, file) => total + file.size, 0) > 10 * 1024 * 1024) return "Choose images totalling 10 MB or less.";
  return "";
}

export function validateIconSelections(selections) {
  const errors = selections.map(validateIcons);
  if (errors.some(Boolean)) return errors;
  const combinedError = validateIcons(selections.flat());
  if (combinedError) {
    // The combined limit has no single offending file; focus the first selection.
    errors[selections.findIndex(files => files.length)] = combinedError;
  }
  return errors;
}

export async function makeIconAttachment(file, contributionNumber) {
  const error = validateIcons([file]);
  if (error) throw new Error(error);
  return {
    filename: `contribution-${contributionNumber}-icon.${imageExtensions[file.type]}`,
    type: file.type,
    content: encodeBytes(new Uint8Array(await file.arrayBuffer()))
  };
}

// MIME encoding keeps Unicode, long answers and header-like body text intact.
export function makeEmailFile(draft, recipient, attachments = []) {
  if (/[\r\n<>]/.test(recipient)) throw new Error("Invalid email recipient");
  const subject = Array.from(draft.subject.matchAll(/.{1,10}/gu), match => `=?UTF-8?B?${base64(match[0])}?=`).join(`${newline} `);
  const body = base64(draft.body).match(/.{1,76}/g)?.join(newline) ?? "";
  const headers = ["X-Unsent: 1", `To: ${recipient}`, `Subject: ${subject}`, "MIME-Version: 1.0"];
  const textPart = ['Content-Type: text/plain; charset="UTF-8"', "Content-Transfer-Encoding: base64", "", body, ""].join(newline);
  if (!attachments.length) return [...headers, textPart].join(newline);
  // Base64 payloads cannot contain this boundary. Filenames are generated locally.
  const boundary = "=_indie_contribution_images";
  const parts = attachments.map(attachment => {
    if (!imageExtensions[attachment.type] || !/^contribution-[1-9][0-9]*-icon\.(png|jpg|webp)$/.test(attachment.filename)
      || !/^[A-Za-z0-9+/]*={0,2}$/.test(attachment.content)) throw new Error("Invalid image attachment");
    return [`Content-Type: ${attachment.type}`, `Content-Disposition: attachment; filename="${attachment.filename}"`,
      "Content-Transfer-Encoding: base64", "", attachment.content.match(/.{1,76}/g)?.join(newline) ?? "", ""].join(newline);
  });
  return [...headers, `Content-Type: multipart/mixed; boundary="${boundary}"`, "",
    `--${boundary}`, textPart, ...parts.flatMap(part => [`--${boundary}`, part]), `--${boundary}--`, ""].join(newline);
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
  let revision = 0;

  function invalidateDraft() {
    revision++;
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
    // Reveal invalid optional fields before the browser tries to focus them.
    let details = event.target.closest("details");
    while (details) {
      details.open = true;
      details = details.parentElement.closest("details");
    }
  }, true);
  form.addEventListener("change", () => {
    invalidateDraft();
    validateImageFields();
  });

  const resources = () => [...form.querySelectorAll("fieldset[data-resource]")];
  const offers = resource => [...resource.querySelectorAll("fieldset[data-offer]")];
  const iconFields = () => [...form.querySelectorAll("[data-product-icon]")];
  function validateImageFields() {
    const fields = iconFields();
    const errors = validateIconSelections(fields.map(field => [...field.files]));
    fields.forEach((field, index) => {
      field.setCustomValidity(errors[index]);
      field.parentElement.querySelector("[data-remove-icon]").hidden = !field.files.length;
    });
    document.getElementById("prepare-draft").textContent = fields.some(field => field.files.length) ? "Prepare draft with images" : "Open email draft";
    return !errors.some(Boolean);
  }

  function renumberResources() {
    const fields = resources();
    fields.forEach((fieldset, index) => {
      fieldset.querySelector("legend").textContent = `${index + 1}. App, game or other resource`;
      const button = fieldset.querySelector("[data-remove-resource]");
      button.querySelector("[data-action-label]").textContent = `Remove contribution ${index + 1}`;
      button.hidden = fields.length === 1;
      fieldset.querySelector("[data-remove-icon]").setAttribute("aria-label", `Remove image from contribution ${index + 1}`);
      fieldset.querySelector("[data-add-offer]").setAttribute("aria-label", `Add another offer to contribution ${index + 1}`);
      const entries = offers(fieldset);
      entries.forEach((offer, offerIndex) => {
        offer.querySelector("legend").textContent = `${offerIndex + 1}. Offer`;
        const remove = offer.querySelector("[data-remove-offer]");
        remove.querySelector("[data-action-label]").textContent = `Remove offer ${offerIndex + 1}`;
        remove.setAttribute("aria-label", `Remove offer ${offerIndex + 1} from contribution ${index + 1}`);
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
    renumberResources();
    clone.querySelector("textarea[required]").focus();
    status.textContent = `Contribution ${resources().length} added.`;
  });

  form.addEventListener("click", event => {
    const removeIcon = event.target.closest("[data-remove-icon]");
    if (removeIcon) {
      invalidateDraft();
      const field = removeIcon.parentElement.querySelector("[data-product-icon]");
      const contributionNumber = resources().indexOf(field.closest("[data-resource]")) + 1;
      field.value = "";
      validateImageFields();
      field.focus();
      status.textContent = `Image removed from contribution ${contributionNumber}.`;
      return;
    }
    const addOffer = event.target.closest("[data-add-offer]");
    if (addOffer) {
      invalidateDraft();
      const resource = addOffer.closest("[data-resource]");
      const clone = cloneFields(offerTemplate, `${resource.id}-offer-${++offerID}`);
      offers(resource).at(-1).after(clone);
      renumberResources();
      clone.querySelector("textarea").focus();
      status.textContent = `Offer ${offers(resource).length} added to contribution ${resources().indexOf(resource) + 1}.`;
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
      status.textContent = `Offer ${offerNumber} removed from contribution ${resourceNumber}. ${remaining} ${remaining === 1 ? "offer remains" : "offers remain"}.`;
      return;
    }
    const remove = event.target.closest("[data-remove-resource]");
    if (!remove || resources().length === 1) return;
    invalidateDraft();
    const resource = remove.closest("fieldset[data-resource]");
    const resourceNumber = resources().indexOf(resource) + 1;
    resource.remove();
    validateImageFields();
    renumberResources();
    addButton.focus();
    const remaining = resources().length;
    status.textContent = `Contribution ${resourceNumber} removed. ${remaining} ${remaining === 1 ? "contribution remains" : "contributions remain"}.`;
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

  form.addEventListener("submit", async event => {
    event.preventDefault();
    validateImageFields();
    if (!form.reportValidity()) return;
    const draftRevision = ++revision;
    const draft = makeContributionEmail(readForm(), form.dataset.recipient);
    const selected = resources().flatMap((resource, index) => {
      const file = resource.querySelector("[data-product-icon]").files[0];
      return file ? [{ file, number: index + 1 }] : [];
    });
    let attachments;
    try {
      attachments = await Promise.all(selected.map(({ file, number }) => makeIconAttachment(file, number)));
    } catch {
      if (revision !== draftRevision) return;
      status.textContent = "An image could not be read. Choose the image again, or remove it and attach it in your email app.";
      return;
    }
    // Edits or another submission while reading files must not resurrect an old draft.
    if (revision !== draftRevision) return;
    if (downloadURL) URL.revokeObjectURL(downloadURL);
    currentDraft = draft;
    subjectField.value = draft.subject;
    bodyField.value = draft.body;
    emailLink.href = draft.mailto;
    downloadURL = URL.createObjectURL(new Blob([makeEmailFile(draft, form.dataset.recipient, attachments)], { type: "message/rfc822" }));
    downloadLink.href = downloadURL;
    emailLink.textContent = attachments.length ? "Open email app (text only)" : "Open email app";
    document.getElementById("draft-attachment-note").textContent = attachments.length
      ? `${attachments.length} image(s) included in the email file. Download it to send your images, or attach them yourself after opening the text draft.` : "";
    preview.hidden = false;
    const longHint = draft.isLong ? " If your app cannot open this long draft, download the complete email file below or use Copy email text." : "";
    if (attachments.length) {
      status.textContent = "Your draft with images is ready. Download the email file below and open it in your email app to review and send. Nothing has been sent.";
      downloadLink.focus();
    } else if (event.submitter?.value === "preview") {
      status.textContent = `Your email preview is ready. Nothing has been sent.${longHint}`;
      bodyField.focus();
    } else {
      status.textContent = `Opening your email app with the recipient, subject and complete text. Nothing has been sent by this website.${longHint}`;
      window.location.assign(draft.mailto);
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

  renumberResources();
  form.hidden = false;
}

if (typeof document !== "undefined") initialiseForm();
