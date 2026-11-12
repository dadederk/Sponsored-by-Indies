import test from "node:test";
import assert from "node:assert/strict";
import { makeContributionEmail, makeEmailFile, LONG_EMAIL_HINT_LENGTH } from "../Assets/contribution.mjs";

const recipient = "hello@accessibilityUpTo11.com";
const offer = overrides => ({kind:"Free", audience:"Every eligible attendee", ...overrides});
const proposal = overrides => ({
  name: "Alex Example", email: "alex@example.com", conference: "ARCTIC 2027",
  connection: "Past speaker", quote: "A lovely community.",
  resources: [{product:"Example App",url:"https://example.com/app?a=1&b=2#details",category:"App",description:"A useful tool.",offers:[offer()]}],
  ...overrides
});

test("mailto includes recipient, subject and complete body without interpreting URL characters as headers", () => {
  const draft = makeContributionEmail(proposal(), recipient);
  const url = new URL(draft.mailto);
  assert.equal(url.protocol, "mailto:");
  assert.equal(url.pathname, recipient);
  assert.equal(url.searchParams.get("subject"), draft.subject);
  assert.equal(url.searchParams.get("body"), draft.body);
  assert.equal([...url.searchParams].length, 2);
  assert.ok(draft.body.includes("https://example.com/app?a=1&b=2#details"));
});

test("Unicode and multiline answers survive email preparation", () => {
  const draft = makeContributionEmail(proposal({name:"Álex & Jo",quote:"Hello 👋\nIt’s a warm community — 100%."}), recipient);
  const body = new URL(draft.mailto).searchParams.get("body");
  assert.ok(body.includes("Álex & Jo"));
  assert.ok(body.includes("Hello 👋\r\nIt’s a warm community — 100%."));
  assert.ok(!body.replace(/\r\n/g, "").includes("\n"));
});

test("two resources retain their three distinct offers, prices, durations and deadlines", () => {
  const input = proposal();
  input.resources[0].offers = [offer({plan:"Annual",regularPrice:"USD 9.99/year",duration:"One year",validUntil:"2027-03-01"}),
    offer({kind:"Percentage discount",discount:"50%",plan:"Lifetime",regularPrice:"USD 29.99",duration:"Lifetime",conditions:"Choose one offer."})];
  input.resources.push({product:"Example Game",url:"https://example.com/game",category:"Game",description:"A game.",offers:[offer({regularPrice:"GBP 1.99"})]});
  const body = makeContributionEmail(input, recipient).body;
  const [first, second] = body.split("RESOURCE 2");
  assert.ok(first.includes("Offer 1\r\nOffer type: Free\r\nAttendee price/discount: Free (0)"));
  assert.ok(first.includes("Offer 2\r\nOffer type: Percentage discount\r\nAttendee price/discount: 50%"));
  assert.ok(first.includes("Last day to claim: 2027-03-01"));
  assert.ok(first.includes("Access duration: One year"));
  assert.ok(first.includes("Usual price and currency: USD 29.99"));
  assert.ok(second.includes("Name: Example Game"));
  assert.ok(second.includes("Usual price and currency: GBP 1.99"));
  assert.ok(!second.includes("Offer 2"));
});

test("free requires no manually entered zero and prize quantities stay with the prize offer", () => {
  const input = proposal();
  input.resources[0].offers.push(offer({audience:"Limited prize licenses",quantity:"5"}));
  const body = makeContributionEmail(input, recipient).body;
  assert.equal(body.match(/Attendee price\/discount: Free \(0\)/g).length, 2);
  assert.equal(body.match(/Prize licenses: 5/g).length, 1);
});

test("long responses keep the entire email body in the handoff", () => {
  const input = proposal();
  input.resources[0].offers[0].conditions = "Detailed terms. ".repeat(500) + "LAST ANSWER";
  const draft = makeContributionEmail(input, recipient);
  assert.ok(draft.mailto.length > LONG_EMAIL_HINT_LENGTH);
  assert.equal(draft.isLong, true);
  assert.ok(draft.body.includes(input.resources[0].offers[0].conditions));
  assert.equal(new URL(draft.mailto).searchParams.get("body"), draft.body);
});

test("header-like text stays inside the subject and body", () => {
  const draft = makeContributionEmail(proposal({name:"Alex\r\ncc: nobody@example.com"}), recipient);
  assert.ok(!/[\r\n]/.test(draft.subject));
  assert.equal(new URL(draft.mailto).searchParams.get("cc"), null);
});

test("recipient delimiters remain in the address", () => {
  const address = 'team?tag#north&events@example.org';
  const draft = makeContributionEmail(proposal(), address);
  const url = new URL(draft.mailto);
  assert.equal(decodeURIComponent(url.pathname), address);
  assert.equal(url.hash, '');
  assert.equal(url.searchParams.get('subject'), draft.subject);
  assert.equal(url.searchParams.has('tag'), false);
  assert.equal(url.searchParams.get('body'), draft.body);
});

test("email file preserves the recipient and Unicode subject/body, with safe MIME line lengths", () => {
  const input = proposal({name:"Álex 👋",quote:"Hello\nBcc: keep this in the body"});
  input.resources[0].offers[0].conditions = "Terms € £ 👋 ".repeat(800) + "LAST ANSWER";
  const draft = makeContributionEmail(input, recipient);
  const file = makeEmailFile(draft, recipient);
  const [headers, body] = file.split("\r\n\r\n");
  assert.ok(headers.startsWith(`X-Unsent: 1\r\nTo: ${recipient}\r\n`));
  const encodedSubject = headers.match(/=\?UTF-8\?B\?([^?]+)\?=/g).map(word => Buffer.from(word.slice(10, -2), "base64").toString("utf8")).join("");
  assert.equal(encodedSubject, draft.subject);
  assert.equal(Buffer.from(body.replace(/\s/g, ""), "base64").toString("utf8"), draft.body);
  assert.ok(file.split("\r\n").every(line => line.length <= 78));
  assert.ok(!headers.includes("Bcc:"));
  assert.throws(() => makeEmailFile(draft, "hello@example.com\r\nBcc: other@example.com"));
});
