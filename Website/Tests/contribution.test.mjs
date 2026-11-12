import test from "node:test";
import assert from "node:assert/strict";
import { makeContributionEmail, MAILTO_HANDOFF_LIMIT } from "../Assets/contribution.mjs";

const recipient = "hello@accessibilityUpTo11.com";
const proposal = overrides => ({
  name: "Alex Example", email: "alex@example.com", conference: "ARCTIC 2027",
  connection: "Past speaker", quote: "A lovely community.",
  resources: [{product:"Example App",url:"https://example.com/app?a=1&b=2#details",category:"App",description:"A useful tool.",offer:"50% off for attendees."}],
  ...overrides
});

test("mailto body and subject round-trip without treating product URL characters as headers", () => {
  const draft = makeContributionEmail(proposal(), recipient);
  const url = new URL(draft.mailto);
  assert.equal(url.protocol, "mailto:");
  assert.equal(url.pathname, recipient);
  assert.equal(url.searchParams.get("subject"), draft.subject);
  assert.equal(url.searchParams.get("body"), draft.body);
  assert.equal([...url.searchParams].length, 2);
  assert.ok(draft.body.includes("https://example.com/app?a=1&b=2#details"));
});

test("Unicode, quotes, percentages and multiline answers survive email preparation", () => {
  const draft = makeContributionEmail(proposal({name:"Álex & Jo",quote:"Hello 👋\nIt’s a warm community — 100%."}), recipient);
  const body = new URL(draft.mailto).searchParams.get("body");
  assert.ok(body.includes("Álex & Jo"));
  assert.ok(body.includes("Hello 👋\r\nIt’s a warm community — 100%."));
  assert.ok(!body.replace(/\r\n/g, "").includes("\n"));
});

test("multiple resources retain their individual offers and conditions", () => {
  const input = proposal();
  input.resources.push({product:"Example Book",url:"https://example.com/book",category:"Book",description:"A guide.",offer:"Free digital edition",conditions:"Until 1 March; existing customers too."});
  const body = makeContributionEmail(input, recipient).body;
  assert.ok(body.includes("RESOURCE 1\r\nName: Example App"));
  assert.ok(body.includes("RESOURCE 2\r\nName: Example Book"));
  assert.ok(body.includes("Free digital edition"));
  assert.ok(body.includes("Until 1 March; existing customers too."));
});

test("long responses use the copy fallback without truncating any answers", () => {
  const input = proposal();
  input.resources[0].conditions = "Detailed terms. ".repeat(500) + "LAST ANSWER";
  const draft = makeContributionEmail(input, recipient);
  assert.ok(draft.mailto.length > MAILTO_HANDOFF_LIMIT);
  assert.equal(draft.canHandoff, false);
  assert.ok(draft.body.includes(input.resources[0].conditions));
  assert.ok(draft.body.includes("LAST ANSWER"));
  assert.equal(new URL(draft.blankMailto).searchParams.get("body"), null);
});

test("header-like text stays in the single subject instead of creating mail headers", () => {
  const draft = makeContributionEmail(proposal({name:"Alex\r\ncc: nobody@example.com"}), recipient);
  assert.ok(!/[\r\n]/.test(draft.subject));
  assert.equal(new URL(draft.mailto).searchParams.get("cc"), null);
});

test("recipient delimiters remain in the address without becoming headers or fragments", () => {
  const address = 'team?tag#north&events@example.org';
  const draft = makeContributionEmail(proposal(), address);
  for (const target of [draft.mailto, draft.blankMailto]) {
    const url = new URL(target);
    assert.equal(decodeURIComponent(url.pathname), address);
    assert.equal(url.hash, '');
    assert.equal(url.searchParams.get('subject'), draft.subject);
    assert.equal(url.searchParams.has('tag'), false);
  }
  assert.equal(new URL(draft.mailto).searchParams.get('body'), draft.body);
});
