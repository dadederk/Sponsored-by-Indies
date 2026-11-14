import {test, expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const showcase = 'http://127.0.0.1:4174';
test.beforeEach(async ({page}) => {
  await page.route('**/*', route => ['http://127.0.0.1:4173', showcase].includes(new URL(route.request().url()).origin)
    ? route.continue() : route.abort());
});

for (const path of [showcase, '/by-indies-preview/']) {
  test(`card headings use the space beside their icons: ${path}`, async ({page}) => {
    await page.setViewportSize({width:1440, height:900});
    await page.goto(path);
    for (const scale of ['100%', '200%']) {
      await page.addStyleTag({content:`html { font-size: ${scale} !important; }`});
      const headings = await page.locator('.product-card-heading a').evaluateAll(links => links.map(link => {
        const icon = link.querySelector('img').getBoundingClientRect();
        const text = link.querySelector('.product-card-name').getBoundingClientRect();
        return {name:link.textContent, beside:text.left >= icon.right, overlaps:text.top < icon.bottom && text.bottom > icon.top};
      }));
      expect(headings.length).toBeGreaterThan(0);
      for (const heading of headings) {
        expect(heading.beside, `${heading.name} at ${scale}`).toBe(true);
        expect(heading.overlaps, `${heading.name} at ${scale}`).toBe(true);
      }
    }
  });

  test(`header navigation is vertically centred beside the logo: ${path}`, async ({page}) => {
    await page.setViewportSize({width:640, height:900});
    await page.goto(path);
    const brand = await page.locator('header .brand').boundingBox();
    const navigation = await page.locator('header nav').boundingBox();
    expect(navigation.x).toBeGreaterThan(brand.x + brand.width);
    expect(Math.abs((brand.y + brand.height / 2) - (navigation.y + navigation.height / 2))).toBeLessThan(1);
  });

  test(`builder names remain readable with double text on a narrow screen: ${path}`, async ({page}) => {
    await page.setViewportSize({width:320, height:800});
    await page.goto(path);
    await page.addStyleTag({content:'html { font-size: 200% !important; }'});
    const names = page.locator('.builder-row > :last-child > p:first-child');
    expect(await names.count()).toBeGreaterThan(0);
    // A first name must fit as a word rather than a vertical column of letters.
    for (const name of await names.all()) {
      const lines = await name.evaluate(element => {
        const text = element.firstChild;
        const range = document.createRange();
        range.setStart(text, 0);
        range.setEnd(text, text.textContent.split(' ')[0].length);
        return range.getClientRects().length;
      });
      expect(lines).toBe(1);
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  });
}

test('showcase introduces the projects and individual builders accessibly', async ({page}) => {
  await page.goto(showcase);
  await expect(page.getByRole('link', {name:'By Indies. Home'})).toHaveCount(2);
  await expect(page.locator('header').getByRole('link', {name:'Sponsored by Indies', exact:true}))
    .toHaveAttribute('href', 'https://sponsored.byindies.com/');
  const dee = page.locator('#project-dee');
  await expect(page.locator('.showcase-card')).toHaveCount(6);
  await expect(dee.locator('.builder-row')).toHaveCount(1);
  await expect(dee.getByText('Noam Efergan', {exact:true})).toBeVisible();
  await expect(dee.getByRole('link', {name:'Website for Noam Efergan', exact:true})).toHaveAttribute('href', 'https://nowham.dev/');
  await expect(dee.getByRole('link', {name:'Twitter for Noam Efergan', exact:true})).toHaveAttribute('href', 'https://x.com/No_Wham');
  await expect(dee.locator('.showcase-builders').getByText('Dee Training', {exact:true})).toHaveCount(0);
  await expect(page.locator('.showcase-card .product-card-benefits')).toHaveCount(0);
  await expect(page.locator('footer nav a')).toHaveText(['Sponsored by Indies','Terms & conditions']);
  await expect(page.getByRole('heading', {name:'More indie discoveries.'})).toBeVisible();
  const result = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa','wcag22aa']).analyze();
  expect(result.violations).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.locator('#project-xarra').scrollIntoViewIfNeeded();
  await expect.poll(() => page.locator('#project-xarra .builder-portrait').evaluate(image => image.naturalWidth)).toBeGreaterThan(0);
});

test('project links target the correct bundle card and footer connects both sites', async ({page}) => {
  await page.goto(showcase);
  const link = page.locator('#project-xarra .showcase-bundles a').first();
  const target = new URL(await link.getAttribute('href'));
  expect(target.origin).toBe('https://sponsored.byindies.com');
  expect(target.hash).toBe('#project-xarra');
  await page.goto(`http://127.0.0.1:4173${target.pathname}${target.hash}`);
  await expect(page.locator('#project-xarra')).toBeVisible();
  await expect(page.locator('#project-xarra').getByRole('heading', {name:/Xarra!/})).toBeVisible();
  await expect(page.locator('footer').getByRole('link', {name:'By Indies',exact:true})).toHaveAttribute('href','https://byindies.com/');
  await expect(page.locator('footer nav a')).toHaveText(['For conferences','For indies','By Indies','Terms & conditions']);
});

test('visitors can review the showcase entirely on the Sponsored site', async ({page}) => {
  await page.goto('/by-indies-preview/');
  await expect(page).toHaveURL('/by-indies-preview/');
  const homeLinks = page.getByRole('link', {name:'By Indies. Home',exact:true});
  await expect(homeLinks).toHaveCount(2);
  await expect(homeLinks.first()).toHaveAttribute('href','/by-indies-preview/');
  await expect(page.locator('header').getByRole('link', {name:'Sponsored by Indies',exact:true})).toHaveAttribute('href','/');
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute('content','noindex, follow');
  await expect(page.locator('.showcase-card')).toHaveCount(6);
  const result = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa','wcag22aa']).analyze();
  expect(result.violations).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.locator('#project-xarra .showcase-bundles a').first().click();
  await expect(page).toHaveURL(/\/conferences\/[^/]+\/[^/]+\/#project-xarra$/);
  await expect(page.locator('#project-xarra')).toBeVisible();
});
