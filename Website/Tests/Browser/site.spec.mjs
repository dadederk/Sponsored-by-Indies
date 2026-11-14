import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFile, readdir } from 'node:fs/promises';

// Follow an approved edition from the catalogue, so adding conferences needs no test rewrite.
const data = new URL('../../Data/Conferences/', import.meta.url);
const records = await Promise.all((await readdir(data)).filter(name => name.endsWith('.json')).sort()
  .map(async name => JSON.parse(await readFile(new URL(name, data), 'utf8'))));
const record = records.find(record => record.offers.some(offer => offer.publicationApproved));
if (!record) throw new Error('Browser checks need an edition with approved offers.');
const product = record.offers.find(offer => offer.publicationApproved);
const edition = record.editions.find(edition => edition.id === product.editionID);
const bundlePath = `/conferences/${record.conference.slug}/${edition.slug}/`;
const termsName = `Offer terms for ${product.productName}`;
const formPath = '/participate/indies/';

test.beforeEach(async ({ page }) => {
  // These checks exercise the generated site without contacting makers or opening mail apps.
  await page.route('**/*', route => new URL(route.request().url()).origin === 'http://127.0.0.1:4173'
    ? route.continue() : route.abort());
});

async function fillProposal(page) {
  if (await page.locator('#interest-form').getAttribute('open') === null) {
    await page.locator('#interest-form > summary').press('Enter');
  }
  await page.getByLabel('Name (required)', { exact: true }).fill('Example Maker');
  await page.getByLabel('Contact email (required)', { exact: true }).fill('maker@example.org');
  await page.getByLabel('Conference you’d like to contribute to (required)', { exact: true }).fill('Example Conference 2027');
  await page.getByLabel('What would you like to offer? (required)', { exact: true }).first()
    .fill('One month of Example App: https://example.org/');
}

async function expectAccessible(page) {
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
  expect(results.violations).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
}

test('visitors can discover an edition using the keyboard', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('link', { name: 'Find your conference', exact: true }).first().press('Enter');
  await expect(page).toHaveURL('/conferences/');
  // The directory may feature a later edition; its conference hub always lists the archive.
  await page.goto(`/conferences/${record.conference.slug}/`);
  await page.locator(`main a[href="${bundlePath}"]`).first().press('Enter');
  await expect(page).toHaveURL(bundlePath);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(`${record.conference.name} ${edition.label}`);
});

test('offer dialogs have a name, contain keyboard focus and restore it on Escape', async ({ page, browserName }) => {
  await page.goto(bundlePath);
  const trigger = page.getByRole('link', { name: termsName, exact: true });
  await trigger.press('Enter');
  const dialog = page.getByRole('dialog', { name: termsName, exact: true });
  await expect(dialog).toBeVisible();
  await expect(dialog).toHaveAttribute('aria-modal', 'true');
  await expect(dialog).toBeFocused();
  const close = dialog.getByRole('button', { name: 'Close', exact: true });
  await close.press('Shift+Tab');
  // macOS WebKit may require Option to include links in keyboard navigation.
  if (browserName === 'webkit' && process.platform === 'darwin' &&
      !await dialog.evaluate(element => element.contains(document.activeElement))) {
    await close.press('Alt+Shift+Tab');
  }
  await expect(dialog.locator(':focus')).toHaveCount(1);
  await expectAccessible(page);
  await dialog.locator(':focus').press('Escape');
  await expect(dialog).toBeHidden();
  await expect(trigger).toBeFocused();
});

for (const script of ['bootstrap.bundle.min.js', 'offer-terms.mjs']) {
  test(`terms remain readable when ${script} cannot load`, async ({ page }) => {
    await page.route(`**/${script}*`, route => route.abort());
    await page.goto(bundlePath);
    const fallback = page.locator('.product-card details').filter({ has: page.getByText(termsName, { exact: true }) });
    await expect(fallback).toBeVisible();
    await fallback.locator('summary').press('Enter');
    await expect(fallback).toHaveAttribute('open', '');
    await expect(fallback).toContainText(product.terms);
    await expect(fallback).toContainText(product.redemptionInstructions);
  });
}

test('invalid optional fields are revealed and focused before a draft is prepared', async ({ page }) => {
  await page.goto(formPath);
  await page.locator('#interest-form > summary').press('Enter');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(page.getByLabel('Name (required)', { exact: true })).toBeFocused();
  await fillProposal(page);
  const more = page.getByText('More about you (optional)', { exact: true });
  await more.click();
  const website = page.getByLabel('Website (optional)', { exact: true });
  await website.fill('not a URL');
  await more.click();
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(website).toBeVisible();
  await expect(website).toBeFocused();
  await expect(page.getByRole('heading', { name: 'Your email draft', exact: true })).toBeHidden();
  const name = page.getByLabel('Name (required)', { exact: true });
  await name.fill('');
  await more.click();
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(website).toBeVisible();
  await expect(name).toBeFocused();
});

test('a preview preserves answers and is invalidated when the proposal changes', async ({ page }) => {
  await page.goto(formPath);
  await fillProposal(page);
  await page.getByRole('button', { name: 'Preview email first' }).click();
  const body = page.getByLabel('Email text', { exact: true });
  await expect(body).toBeFocused();
  await expect(body).toHaveValue(/Example Maker[\s\S]*One month of Example App/);
  const handoff = new URL(await page.getByRole('link', { name: 'Open email app', exact: true }).getAttribute('href'));
  expect(handoff.protocol).toBe('mailto:');
  // Textarea values normalize line endings; email URLs retain MIME's CRLF.
  expect(handoff.searchParams.get('body').replace(/\r\n/g, '\n')).toBe(await body.inputValue());
  await expectAccessible(page);
  await page.getByLabel('Name (required)', { exact: true }).fill('Updated Maker');
  await expect(body).toBeHidden();
  await expect(page.getByRole('status')).toContainText('Your answers changed');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(body).toHaveValue(/Updated Maker/);
});

test('adding and removing contributions preserves labels, answers and useful focus', async ({ page }) => {
  await page.goto(formPath);
  await fillProposal(page);
  const addOffer = page.getByRole('button', { name: 'Add another offer to contribution 1', exact: true });
  await addOffer.click();
  const proposals = page.getByLabel('What would you like to offer? (required)', { exact: true });
  await expect(proposals.nth(1)).toBeFocused();
  await proposals.nth(1).fill('A second offer.');
  await page.getByRole('button', { name: 'Remove offer 2 from contribution 1', exact: true }).click();
  await expect(addOffer).toBeFocused();
  const addResource = page.getByRole('button', { name: 'Add another app, game or other resource', exact: true });
  await addResource.click();
  await expect(proposals.nth(1)).toBeFocused();
  await expectAccessible(page);
  const brokenLabels = await page.locator('label[for]').evaluateAll(labels => labels
    .filter(label => document.querySelectorAll(`[id="${label.htmlFor}"]`).length !== 1).map(label => label.htmlFor));
  expect(brokenLabels).toEqual([]);
  await page.getByRole('button', { name: 'Remove contribution 2', exact: true }).click();
  await expect(addResource).toBeFocused();
  await expect(proposals).toHaveCount(1);
  await expect(proposals).toHaveValue('One month of Example App: https://example.org/');
});

test('an image draft downloads as an email file with its attachment', async ({ page }) => {
  await page.goto(formPath);
  await fillProposal(page);
  await page.getByText('Product details and icon (optional)', { exact: true }).click();
  const icon = page.getByLabel('App icon or product image (optional)', { exact: true });
  await icon.setInputFiles({ name: 'unsupported.svg', mimeType: 'image/svg+xml', buffer: Buffer.from('<svg/>') });
  await expect(icon).toHaveJSProperty('validationMessage', 'Choose a PNG, JPEG or WebP image.');
  await page.getByRole('button', { name: 'Remove image from contribution 1', exact: true }).click();
  await expect(icon).toBeFocused();
  await expect(icon).toHaveJSProperty('validationMessage', '');
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=', 'base64');
  await icon.setInputFiles({ name: 'icon.png', mimeType: 'image/png', buffer: png });
  await page.getByRole('button', { name: 'Prepare draft with images', exact: true }).click();
  const downloadLink = page.getByRole('link', { name: 'Download email file (.eml)', exact: true });
  await expect(downloadLink).toBeFocused();
  await expect(page.getByRole('status')).toContainText('Nothing has been sent');
  const downloading = page.waitForEvent('download');
  await downloadLink.click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe('indie-contribution.eml');
  const email = await readFile(await download.path(), 'utf8');
  expect(email).toContain('Content-Type: multipart/mixed;');
  expect(email).toContain('filename="contribution-1-icon.png"');
  expect(email.replace(/\r\n/g, '')).toContain(png.toString('base64'));
});

test('conference enquiries disclose, validate, preview and invalidate without losing answers', async ({ page }) => {
  await page.goto('/participate/conferences/');
  const disclosure = page.locator('#interest-form');
  await expect(disclosure).not.toHaveAttribute('open', '');
  await disclosure.locator('summary').press('Enter');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(page.getByLabel('Name (required)', { exact: true })).toBeFocused();
  await page.getByLabel('Name (required)', { exact: true }).fill('Example Organiser');
  await page.getByLabel('Contact email (required)', { exact: true }).fill('organiser@example.org');
  await page.getByLabel('Conference name (required)', { exact: true }).fill('ExampleConf');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  const body = page.getByLabel('Email text', { exact: true });
  await expect(body).toBeFocused();
  await expect(body).toHaveValue(/Example Organiser[\s\S]*ExampleConf/);
  const minimal = await body.inputValue();
  expect(minimal).not.toContain('Approximate attendee numbers:');
  const handoff = new URL(await page.getByRole('link', { name: 'Open email app', exact: true }).getAttribute('href'));
  expect(handoff.protocol).toBe('mailto:');
  expect(handoff.searchParams.get('body').replace(/\r\n/g, '\n')).toBe(minimal);
  await expectAccessible(page);
  await page.getByLabel('Next edition and dates (optional)', { exact: true }).fill('February 2027, dates to be confirmed');
  await expect(body).toBeHidden();
  await expect(page.getByRole('status')).toContainText('Your answers changed');
  await page.getByLabel('Approximate attendee numbers (optional)', { exact: true }).fill('150–200');
  const website = page.getByLabel('Website (optional)', { exact: true });
  await website.fill('not a URL');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(website).toBeFocused();
  await website.fill('https://example.org/?a=1&b=2');
  await page.getByRole('button', { name: 'Preview email first' }).click();
  await expect(body).toHaveValue(/dates to be confirmed[\s\S]*150–200/);
  const downloading = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Download email file (.eml)', exact: true }).click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe('conference-interest.eml');
  const file = await readFile(await download.path(), 'utf8');
  expect(file).toContain('X-Unsent: 1');
  const decoded = Buffer.from(file.split('\r\n\r\n')[1].replace(/\s/g, ''), 'base64').toString('utf8');
  expect(decoded.replace(/\r\n/g, '\n')).toBe(await body.inputValue());
});

for (const [path, form] of [[formPath, '#contribution-form'], ['/participate/conferences/', '#conference-interest-form']]) {
  test(`email remains available when shared draft tools fail: ${path}`, async ({ page }) => {
    await page.route('**/email-draft.mjs*', route => route.abort());
    await page.goto(path);
    await page.locator('#interest-form > summary').press('Enter');
    await expect(page.locator(form)).toBeHidden();
    await expect(page.locator('#form-fallback')).toBeVisible();
    await expect(page.getByRole('link', { name: /Express (indie|conference) interest/ })).toHaveAttribute('href', /^mailto:/);
  });
}

test('direct email and native terms work without JavaScript', async ({ browser, baseURL }, testInfo) => {
  const context = await browser.newContext({ javaScriptEnabled: false, baseURL, viewport: testInfo.project.use.viewport });
  try {
    const page = await context.newPage();
    await page.goto(formPath);
    await expect(page.locator('#contribution-form')).toBeHidden();
    await expect(page.getByRole('link', { name: 'Express indie interest', exact: true })).toHaveAttribute('href', /^mailto:/);
    await page.locator('#interest-form > summary').press('Enter');
    await expect(page.locator('#form-fallback')).toBeVisible();
    await page.goto('/participate/conferences/');
    await expect(page.locator('#conference-interest-form')).toBeHidden();
    await expect(page.getByRole('link', { name: 'Express conference interest', exact: true })).toHaveAttribute('href', /^mailto:/);
    await page.locator('#interest-form > summary').press('Enter');
    await expect(page.locator('#form-fallback')).toBeVisible();
    await page.goto(bundlePath);
    const fallback = page.locator('.product-card details').filter({ has: page.getByText(termsName, { exact: true }) });
    await fallback.locator('summary').press('Enter');
    await expect(fallback).toContainText(product.terms);
    await expect(fallback).toHaveAttribute('open', '');
  } finally {
    await context.close();
  }
});

test('the wordmark remains visible when text is enlarged', async ({ page }) => {
  await page.goto('/');
  await page.addStyleTag({ content: 'html { font-size: 200%; }' });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  for (const brand of await page.locator('.brand').all()) {
    const bounds = await brand.boundingBox();
    expect(bounds.x).toBeGreaterThanOrEqual(0);
    expect(bounds.x + bounds.width).toBeLessThanOrEqual(page.viewportSize().width);
    await expect(brand).toHaveAccessibleName(/Sponsored by Indies/);
  }
});

for (const path of ['/', '/conferences/', `/conferences/${record.conference.slug}/`, bundlePath, `${bundlePath}access/`, '/participate/', '/participate/conferences/', formPath, '/terms/']) {
  test(`page is accessible and fits the viewport: ${path}`, async ({ page }) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(path);
    await expectAccessible(page);
    expect(errors).toEqual([]);
  });
}
