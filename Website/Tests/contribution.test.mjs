import test from "node:test";
import assert from "node:assert/strict";
import { makeContributionEmail, makeEmailFile, LONG_EMAIL_HINT_LENGTH, validateIcons, validateIconSelections, makeIconAttachment } from "../Assets/contribution.mjs";

const recipient = "hello@accessibilityUpTo11.com";
const offer = overrides => ({proposal:"Free access to Example App: https://example.com/app", ...overrides});
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

test("minimal proposals need no structured product or offer details", () => {
  const body = makeContributionEmail(proposal({connection:"", quote:"", resources:[{offers:[offer()]}]}), recipient).body;
  assert.ok(body.includes("Free access to Example App: https://example.com/app"));
  assert.ok(!body.includes("My connection:"));
  assert.ok(!body.includes("Offer type:"));
  assert.ok(!body.includes("Usual price"));
});

test("multiple contributions keep distinct free-text offers and Markdown links", () => {
  const input = proposal();
  input.resources[0].offers = [offer({proposal:"Get 30% off [Xarra!](https://example.com/?a=1&b=2)\nOne year, please."}),
    offer({proposal:"Or five lifetime licenses as prizes."})];
  input.resources.push({offers:[offer({proposal:"Free book: https://example.com/book"})]});
  const body = makeContributionEmail(input, recipient).body;
  const [first, second] = body.split("CONTRIBUTION 2");
  assert.ok(first.includes("1. Offer\r\nGet 30% off [Xarra!](https://example.com/?a=1&b=2)\r\nOne year, please."));
  assert.ok(first.includes("2. Offer\r\nOr five lifetime licenses as prizes."));
  assert.ok(second.includes("Free book: https://example.com/book"));
  assert.ok(!second.includes("2. Offer"));
});

test("long responses keep the entire email body in the handoff", () => {
  const input = proposal();
  input.resources[0].offers[0].proposal = "Detailed terms. ".repeat(500) + "LAST ANSWER";
  const draft = makeContributionEmail(input, recipient);
  assert.ok(draft.mailto.length > LONG_EMAIL_HINT_LENGTH);
  assert.equal(draft.isLong, true);
  assert.ok(draft.body.includes(input.resources[0].offers[0].proposal));
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
  input.resources[0].offers[0].proposal = "Terms € £ 👋 ".repeat(800) + "LAST ANSWER";
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

test("image selection rejects unsupported files and individual or combined oversize", () => {
  const image = size => ({type:"image/png", size});
  assert.equal(validateIcons([]), "");
  assert.equal(validateIcons([image(5 * 1024 * 1024), image(5 * 1024 * 1024)]), "");
  assert.match(validateIcons([{type:"image/svg+xml",size:100}]), /PNG/);
  assert.match(validateIcons([{type:"image/gif",size:100}]), /Choose a PNG, JPEG or WebP image/);
  assert.equal(validateIcons(["image/png", "image/jpeg", "image/webp"].map(type => ({type, size:100}))), "");
  assert.match(validateIcons([image(5 * 1024 * 1024 + 1)]), /5 MB/);
  assert.match(validateIcons([image(4 * 1024 * 1024),image(4 * 1024 * 1024),image(4 * 1024 * 1024)]), /10 MB/);
});

test("image validation associates errors with the affected contribution and clears after removal", () => {
  const valid = {type: "image/png", size: 1024};
  const unsupported = {type: "text/plain", size: 1024};
  const oversized = {type: "image/jpeg", size: 5 * 1024 * 1024 + 1};
  assert.deepEqual(validateIconSelections([[valid], [unsupported], []]), ["", validateIcons([unsupported]), ""]);
  assert.deepEqual(validateIconSelections([[], [valid], [oversized]]), ["", "", validateIcons([oversized])]);
  const large = {type: "image/png", size: 4 * 1024 * 1024};
  assert.deepEqual(validateIconSelections([[], [large], [large], [large]]),
    ["", validateIcons([large, large, large]), "", ""]);
  assert.deepEqual(validateIconSelections([[], [large], [], [large]]), ["", "", "", ""]);
});

test("email attachment preserves binary data and contribution association without filename injection", async () => {
  const bytes = new Uint8Array([137,80,78,71,0,255,13,10]);
  const file = new File([bytes], 'icon"\r\nBcc: example@example.com.png', {type:"image/png"});
  const attachment = await makeIconAttachment(file, 2);
  assert.equal(attachment.filename, "contribution-2-icon.png");
  const draft = makeContributionEmail(proposal(), recipient);
  const email = makeEmailFile(draft, recipient, [attachment]);
  assert.match(email, /Content-Type: multipart\/mixed/);
  const parts = email.split("--=_indie_contribution_images");
  assert.equal(Buffer.from(parts[1].split("\r\n\r\n")[1].trim(), "base64").toString(), draft.body);
  assert.match(parts[2], /filename="contribution-2-icon.png"/);
  assert.deepEqual(new Uint8Array(Buffer.from(parts[2].split("\r\n\r\n")[1].trim(), "base64")), bytes);
  assert.ok(!email.includes("Bcc:"));
  assert.ok(email.split("\r\n").every(line => line.length <= 78));
  assert.throws(() => makeEmailFile(draft, recipient, [{...attachment, type:"image/png\r\nBcc: x"}]));
  assert.throws(() => makeEmailFile(draft, recipient, [{...attachment, type:"image/gif", filename:"contribution-2-icon.gif"}]));
});
