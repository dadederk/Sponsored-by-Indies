import {test, expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const showcase = 'http://127.0.0.1:4174';
test.beforeEach(async ({page}) => {
  await page.route('**/*', route => ['http://127.0.0.1:4173', showcase].includes(new URL(route.request().url()).origin)
    ? route.continue() : route.abort());
});

for (const path of [showcase, '/by-indies-preview/']) {
  test(`project sections align within each row and stack on narrow screens: ${path}`, async ({page}) => {
    await page.setViewportSize({width:1280, height:900});
    await page.goto(path);
    await page.evaluate(() => document.fonts.ready);
    const cards = page.locator('.showcase-card');
    const count = await cards.count();
    expect(count).toBeGreaterThan(1);
    for (const scale of ['100%', '200%']) {
      await page.addStyleTag({content:`html { font-size: ${scale} !important; }`});
      for (let index=0; index+1<count; index+=2) {
        const left = cards.nth(index);
        const right = cards.nth(index+1);
        const leftBox = await left.boundingBox();
        const rightBox = await right.boundingBox();
        expect(rightBox.x).toBeGreaterThanOrEqual(leftBox.x + leftBox.width);
        expect(Math.abs(leftBox.height-rightBox.height)).toBeLessThan(1);
        for (const section of ['.product-card-header', ':scope > p', '.showcase-builders', '.showcase-contributions']) {
          const a = await left.locator(section).boundingBox();
          const b = await right.locator(section).boundingBox();
          expect(Math.abs(a.y-b.y), `${section} at ${scale}`).toBeLessThan(1);
        }
      }
    }
    await page.setViewportSize({width:320, height:800});
    for (let index=0; index+1<count; index++) {
      const a = await cards.nth(index).boundingBox();
      const b = await cards.nth(index+1).boundingBox();
      expect(b.y).toBeGreaterThanOrEqual(a.y+a.height);
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  });

  test(`project permalinks copy and navigate to the selected card: ${path}`, async ({page}) => {
    await page.addInitScript(() => {
      Object.defineProperty(navigator, 'clipboard', {value:{writeText:async value => { window.copiedProjectLink = value; }}});
    });
    await page.goto(path);
    const card = page.locator('#project-xarra');
    const button = card.getByRole('button', {name:'Copy link to Xarra!', exact:true});
    await button.press('Enter');
    await expect(card.getByRole('status')).toHaveText('Link copied.');
    await expect(button.locator('[data-copied-icon]')).toBeVisible();
    await expect(button).toBeFocused();
    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    expect(await page.evaluate(() => window.copiedProjectLink)).toBe(`${canonical}#project-xarra`);
    await page.goto(`${path}#project-xarra`);
    await expect(page.locator(':target')).toHaveAttribute('id', 'project-xarra');
    await expect(card.locator('.product-card-heading')).toBeInViewport();
  });

  test(`project links remain usable when copying or the sharing script fails: ${path}`, async ({page}) => {
    await page.addInitScript(() => {
      Object.defineProperty(navigator, 'clipboard', {value:{writeText:async () => { throw new Error('Denied'); }}});
    });
    await page.goto(path);
    const card = page.locator('#project-xarra');
    await card.getByRole('button', {name:'Copy link to Xarra!', exact:true}).click();
    const field = card.getByRole('textbox', {name:'Link to Xarra!', exact:true});
    await expect(field).toBeVisible();
    await expect(field).toBeFocused();
    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    await expect(field).toHaveValue(`${canonical}#project-xarra`);
    expect(await field.evaluate(input => input.selectionEnd - input.selectionStart)).toBe((await field.inputValue()).length);
    await page.route('**/offer-sharing.mjs*', route => route.abort());
    await page.reload();
    const link = card.getByRole('link', {name:'Link to this project for Xarra!', exact:true});
    await expect(link).toBeVisible();
    await link.press('Enter');
    await expect(page.locator(':target')).toHaveAttribute('id', 'project-xarra');
  });

  test(`discovery cards fit two per row and stack on narrow screens: ${path}`, async ({page}) => {
    await page.goto(path);
    const cards = page.locator('.discovery-card');
    expect(await cards.count()).toBeGreaterThan(1);
    for (const width of [1280, 320]) {
      await page.setViewportSize({width, height:900});
      const first = await cards.nth(0).boundingBox();
      const second = await cards.nth(1).boundingBox();
      if (width === 1280) {
        expect(Math.abs(first.y - second.y)).toBeLessThan(1);
        expect(second.x).toBeGreaterThanOrEqual(first.x + first.width);
      } else {
        expect(second.y).toBeGreaterThanOrEqual(first.y + first.height);
      }
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    }
  });

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
  const helm = page.locator('#project-helm');
  await expect(helm.locator('.builder-row')).toHaveCount(2);
  await expect(helm.getByText('Hidde van der Ploeg', {exact:true})).toBeVisible();
  await expect(helm.getByText('Pol Piella', {exact:true})).toBeVisible();
  await expect(helm.getByRole('link', {name:'Website for Hidde van der Ploeg', exact:true})).toHaveAttribute('href', 'https://hidde.design/');
  await expect(helm.getByRole('link', {name:'Twitter for Pol Piella', exact:true})).toHaveAttribute('href', 'https://x.com/polpielladev');
  await expect(helm.locator('.showcase-builders').getByText('Anima Software', {exact:true})).toHaveCount(0);
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
  await expect(page.locator('#project-helm .builder-row')).toHaveCount(2);
  const result = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa','wcag22aa']).analyze();
  expect(result.violations).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.locator('#project-xarra .showcase-bundles a').first().click();
  await expect(page).toHaveURL(/\/conferences\/[^/]+\/[^/]+\/#project-xarra$/);
  await expect(page.locator('#project-xarra')).toBeVisible();
});
