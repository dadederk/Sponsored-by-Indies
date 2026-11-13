export const newline = "\r\n";
// An advisory only: email apps have different URL limits. Always offer the full link.
export const LONG_EMAIL_HINT_LENGTH = 1900;

export function makeEmailDraft(subject, body, recipient) {
  subject = Array.from(String(subject).replace(/[\r\n]+/g, " ")).slice(0, 100).join("");
  body = String(body).replace(/\r\n|\r|\n/g, newline);
  const address = encodeURIComponent(recipient).replace(/%40/g, "@");
  const mailto = `mailto:${address}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  return { subject, body, mailto, isLong: mailto.length > LONG_EMAIL_HINT_LENGTH };
}

export function encodeBytes(bytes) {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 8192) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
  }
  return btoa(binary);
}

function base64(text) {
  return encodeBytes(new TextEncoder().encode(text));
}

export const imageExtensions = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp" };
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

// One draft interface per page; each form owns how its answers become an email.
export function createEmailDraftController(form) {
  const status = document.getElementById("form-status");
  const preview = document.getElementById("draft-preview");
  const bodyField = document.getElementById("draft-body");
  const subjectField = document.getElementById("draft-subject");
  const emailLink = document.getElementById("draft-email-link");
  const downloadLink = document.getElementById("download-draft");
  const attachmentNote = document.getElementById("draft-attachment-note");
  let currentDraft;
  let downloadURL;
  let revision = 0;

  function invalidate() {
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
  form.addEventListener("input", invalidate);
  form.addEventListener("change", invalidate);
  form.addEventListener("invalid", event => {
    let details = event.target.closest("details");
    let revealed = false;
    while (details) {
      if (!details.open) {
        details.open = true;
        revealed = true;
      }
      details = details.parentElement?.closest("details");
    }
    // WebKit needs layout to catch up after opening a collapsed section.
    if (revealed) requestAnimationFrame(() => form.querySelector("input:invalid, select:invalid, textarea:invalid")?.focus());
  }, true);

  function show(draft, { attachments = [], previewOnly = false } = {}) {
    if (downloadURL) URL.revokeObjectURL(downloadURL);
    currentDraft = draft;
    subjectField.value = draft.subject;
    bodyField.value = draft.body;
    emailLink.href = draft.mailto;
    downloadURL = URL.createObjectURL(new Blob([makeEmailFile(draft, form.dataset.recipient, attachments)], { type: "message/rfc822" }));
    downloadLink.href = downloadURL;
    const hasImages = attachments.length > 0;
    emailLink.classList.toggle("btn-primary", !hasImages);
    emailLink.classList.toggle("btn-secondary", hasImages);
    downloadLink.classList.toggle("btn-primary", hasImages);
    downloadLink.classList.toggle("btn-secondary", !hasImages);
    emailLink.textContent = hasImages ? "Open email app (text only)" : "Open email app";
    attachmentNote.hidden = !hasImages;
    attachmentNote.textContent = hasImages
      ? `${attachments.length} image(s) included in the email file. Download it to send your images, or attach them yourself after opening the text draft.` : "";
    preview.hidden = false;
    const longHint = draft.isLong ? " If your app cannot open this long draft, download the complete email file below or use Copy email text." : "";
    if (hasImages) {
      status.textContent = "Your draft with images is ready. Download the email file below and open it in your email app to review and send. Nothing has been sent.";
      downloadLink.focus();
    } else if (previewOnly) {
      status.textContent = `Your email preview is ready. Nothing has been sent.${longHint}`;
      bodyField.focus();
    } else {
      status.textContent = `Opening your email app with the recipient, subject and complete text. Nothing has been sent by this website.${longHint}`;
      window.location.assign(draft.mailto);
    }
  }

  document.getElementById("copy-draft").addEventListener("click", async () => {
    const draft = currentDraft;
    if (!draft) return;
    try {
      await navigator.clipboard.writeText(draft.body);
      if (currentDraft !== draft) return;
      status.textContent = "Email text copied. Open your email draft, paste the text if needed, then review and send it.";
    } catch {
      if (currentDraft !== draft) return;
      bodyField.focus();
      bodyField.select();
      status.textContent = "Automatic copying is unavailable. The email text is selected; copy it, then paste it into your email draft.";
    }
  });

  return {
    status, invalidate, show,
    begin: () => ++revision,
    isCurrent: token => revision === token,
    reveal() {
      document.getElementById("form-fallback").hidden = true;
      form.hidden = false;
    }
  };
}
