import test from "node:test";
import assert from "node:assert/strict";
import { makeConferenceEmail } from "../Assets/conference-interest.mjs";
import { makeEmailFile } from "../Assets/email-draft.mjs";

const recipient = "hello@accessibilityUpTo11.com";
const enquiry = extra => ({ name: "Alex", email: "alex@example.org", conference: "ExampleConf", ...extra });

test("a minimal conference enquiry needs no optional logistics", () => {
  const draft = makeConferenceEmail(enquiry(), recipient);
  const url = new URL(draft.mailto);
  assert.equal(url.pathname, recipient);
  assert.equal(url.searchParams.get("subject"), "Conference interest — ExampleConf — Alex");
  assert.equal(url.searchParams.get("body"), draft.body);
  assert.match(draft.body, /Name: Alex\r\nContact email: alex@example.org/);
  for (const label of ["Website:", "Next edition and dates:", "Location:", "Approximate attendee numbers:", "Anything else"]) {
    assert.ok(!draft.body.includes(label));
  }
});

test("complete enquiries preserve approximate dates, ranges, URLs and multiline Unicode", () => {
  const data = enquiry({ name: "Álex 👋", website: "https://example.org/?a=1&b=2#about",
    dates: "February 2027, still to be confirmed", location: "Oulu, Finland",
    attendees: "150–200", message: "Hello!\nA little extra — € £ 👋" });
  const draft = makeConferenceEmail(data, recipient);
  const body = new URL(draft.mailto).searchParams.get("body");
  for (const value of [data.name, data.website, data.dates, data.location, data.attendees]) assert.ok(body.includes(value));
  assert.ok(body.includes(data.message.replace(/\n/g, "\r\n")));
  assert.ok(!body.replace(/\r\n/g, "").includes("\n"));
});

test("conference answers cannot create email headers or query parameters", () => {
  const draft = makeConferenceEmail(enquiry({ name: "Alex\r\nBcc: other@example.org",
    conference: "Conf & Community", message: "cc: not-a-header@example.org\n?subject=keep this" }), "team?tag#events@example.org");
  const url = new URL(draft.mailto);
  assert.equal(decodeURIComponent(url.pathname), "team?tag#events@example.org");
  assert.equal(url.hash, "");
  assert.deepEqual([...url.searchParams.keys()], ["subject", "body"]);
  assert.ok(!/[\r\n]/.test(draft.subject));
  assert.ok(draft.body.includes("cc: not-a-header@example.org"));
});

test("long conference drafts retain every answer in both mailto and email files", () => {
  const message = "Conference plans € 👋. ".repeat(200) + "FINAL ANSWER";
  const draft = makeConferenceEmail(enquiry({ message }), recipient);
  assert.equal(draft.isLong, true);
  assert.ok(new URL(draft.mailto).searchParams.get("body").includes(message));
  const file = makeEmailFile(draft, recipient);
  assert.ok(file.startsWith(`X-Unsent: 1\r\nTo: ${recipient}\r\n`));
  const encoded = file.split("\r\n\r\n")[1].replace(/\s/g, "");
  assert.equal(Buffer.from(encoded, "base64").toString("utf8"), draft.body);
});
