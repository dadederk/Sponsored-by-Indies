const newline = "\r\n";
// A conservative handoff threshold, not a limit defined by the mailto standard.
// Longer answers remain complete in the preview and copy fallback.
export const MAILTO_HANDOFF_LIMIT = 1900;

export function makeContributionEmail(data, recipient) {
  const clean = value => String(value ?? "").trim();
  const line = (label, value) => `${label}: ${clean(value) || "To be discussed"}`;
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
      line("Type", resource.category), line("Description", resource.description),
      line("Proposed offer", resource.offer), line("Standard price/currency/period", resource.regularPrice),
      line("Attendee price/discount", resource.attendeePrice),
      line("Availability and redemption", resource.conditions), "");
  });
  lines.push("This is an initial proposal. Final offers and public profile details are still to be agreed.");
  const body = lines.join(newline).replace(/\r\n|\r|\n/g, newline);
  // Keep address characters such as ? and # in the recipient, never in headers.
  const address = encodeURIComponent(recipient).replace(/%40/g, "@");
  const base = `mailto:${address}?subject=${encodeURIComponent(subject)}`;
  const mailto = `${base}&body=${encodeURIComponent(body)}`;
  return { subject, body, mailto, blankMailto: base, canHandoff: mailto.length <= MAILTO_HANDOFF_LIMIT };
}

function initialiseForm() {
  const form = document.getElementById("contribution-form");
  if (!form) return;
  const status = document.getElementById("form-status");
  const preview = document.getElementById("draft-preview");
  const bodyField = document.getElementById("draft-body");
  const subjectField = document.getElementById("draft-subject");
  const emailLink = document.getElementById("draft-email-link");
  const addButton = document.getElementById("add-resource");
  let resourceID = 1;
  let currentDraft;

  function invalidateDraft() {
    if (!currentDraft) return;
    currentDraft = undefined;
    preview.hidden = true;
    status.textContent = "Your answers changed. Prepare a new draft to include the changes.";
  }
  form.addEventListener("input", invalidateDraft);
  form.addEventListener("change", invalidateDraft);

  const resources = () => [...form.querySelectorAll("fieldset[data-resource]")];
  function renumberResources() {
    const fields = resources();
    fields.forEach((fieldset, index) => {
      fieldset.querySelector("legend").textContent = `Resource ${index + 1}`;
      const button = fieldset.querySelector("[data-remove-resource]");
      button.textContent = `Remove resource ${index + 1}`;
      button.hidden = fields.length === 1;
    });
  }

  addButton.addEventListener("click", () => {
    invalidateDraft();
    const source = resources()[0];
    const clone = source.cloneNode(true);
    const oldPrefix = source.id;
    const nextPrefix = `resource-${++resourceID}`;
    clone.id = nextPrefix;
    clone.querySelectorAll("[id],[name],[for],[aria-describedby],[aria-labelledby]").forEach(element => {
      for (const attribute of ["id", "name", "for", "aria-describedby", "aria-labelledby"]) {
        const value = element.getAttribute(attribute);
        if (value?.startsWith(`${oldPrefix}-`)) element.setAttribute(attribute, value.replace(oldPrefix, nextPrefix));
      }
    });
    clone.querySelectorAll("input,textarea,select").forEach(control => {
      if (control.tagName === "SELECT") control.selectedIndex = 0;
      else control.value = "";
    });
    resources().at(-1).after(clone);
    renumberResources();
    clone.querySelector("input").focus();
    status.textContent = `Resource ${resources().length} added.`;
  });

  form.addEventListener("click", event => {
    const remove = event.target.closest("[data-remove-resource]");
    if (!remove || resources().length === 1) return;
    invalidateDraft();
    remove.closest("fieldset[data-resource]").remove();
    renumberResources();
    addButton.focus();
    status.textContent = "Resource removed.";
  });

  function readForm() {
    const value = name => form.elements.namedItem(name)?.value ?? "";
    return {
      name: value("maker-name"), email: value("maker-email"), company: value("maker-company"),
      website: value("maker-website"), socials: value("maker-socials"), assets: value("maker-assets"),
      conference: value("conference"), connection: value("connection"), quote: value("conference-quote"),
      resources: resources().map(fieldset => Object.fromEntries(
        [...fieldset.querySelectorAll("[data-resource-field]")].map(control => [control.dataset.resourceField, control.value])
      ))
    };
  }

  form.addEventListener("submit", event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    currentDraft = makeContributionEmail(readForm(), form.dataset.recipient);
    subjectField.value = currentDraft.subject;
    bodyField.value = currentDraft.body;
    emailLink.href = currentDraft.canHandoff ? currentDraft.mailto : currentDraft.blankMailto;
    preview.hidden = false;
    if (!currentDraft.canHandoff) {
      status.textContent = "Your response is ready, but it is too long for a reliable prefilled email link. Copy the email text below, then use Open email app and paste it into the draft. All your answers are included.";
      bodyField.focus();
    } else if (event.submitter?.value === "preview") {
      status.textContent = "Your email preview is ready. Nothing has been sent.";
      bodyField.focus();
    } else {
      status.textContent = "Opening your email app. Nothing has been sent by this website. If no draft appears, use the preview and copy option below.";
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

  // Reveal only after preventing browser form submission and wiring the draft builder.
  form.hidden = false;
}

if (typeof document !== "undefined") initialiseForm();
