import { newline, makeEmailDraft, createEmailDraftController } from "./email-draft.mjs";

export function makeConferenceEmail(data, recipient) {
  const clean = value => String(value ?? "").trim();
  const line = (label, value) => clean(value) ? `${label}: ${clean(value)}` : null;
  const subject = `Conference interest — ${clean(data.conference)} — ${clean(data.name)}`;
  const body = [
    "Hi! I’d like to explore Sponsored by Indies for our conference.", "",
    line("Name", data.name), line("Contact email", data.email), "",
    line("Conference", data.conference), line("Website", data.website),
    line("Next edition and dates", data.dates), line("Location", data.location),
    line("Approximate attendee numbers", data.attendees), "",
    line("Anything else you’d like us to know", data.message)
  ].filter(line => line !== null).join(newline).trim();
  return makeEmailDraft(subject, body, recipient);
}

function initialiseForm() {
  const form = document.getElementById("conference-interest-form");
  if (!form) return;
  const draftView = createEmailDraftController(form);
  form.addEventListener("submit", event => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const value = name => form.elements.namedItem(name)?.value ?? "";
    const draft = makeConferenceEmail({
      name: value("organiser-name"), email: value("organiser-email"),
      conference: value("conference-name"), website: value("conference-website"),
      dates: value("conference-dates"), location: value("conference-location"),
      attendees: value("conference-attendees"), message: value("conference-message")
    }, form.dataset.recipient);
    draftView.show(draft, { previewOnly: event.submitter?.value === "preview" });
  });
  draftView.reveal();
}

if (typeof document !== "undefined") initialiseForm();
