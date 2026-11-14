import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { attributes, assertCanonicalURL } from './Support/output-checks.mjs';

const website = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(website, path), 'utf8');
const projects = JSON.parse(await read('Data/projects.json'));
const resources = JSON.parse(await read('Data/site.json')).discoveryResources;
const indies = JSON.parse(await read('Data/indies.json'));
const records = await Promise.all((await readdir(join(website, 'Data/Conferences')))
  .filter(name => name.endsWith('.json')).map(async name => JSON.parse(await read(`Data/Conferences/${name}`))));
const approvedProjects = projects.filter(project => records.some(record => record.offers.some(offer =>
  offer.projectID === project.id && offer.publicationApproved && record.participations.some(participation =>
    participation.editionID === offer.editionID && participation.indieID === project.indieID && participation.publicationApproved))));

for (const [directory, sponsoredDirectory, origin, sponsoredOrigin, preview] of [
  ['BuildIndies', 'Build', 'http://localhost:8001', 'http://localhost:8000', true],
  ['BuildIndiesPublic', 'BuildPublic', 'https://byindies.com', 'https://sponsored.byindies.com', false]
]) {
  test(`${directory}: projects, builders, selected discoveries and metadata`, async () => {
    const html = await read(`${directory}/index.html`);
    assert.ok(!html.includes('MEET THE INDIES'));
    assert.ok(!html.includes('A little generosity, a lot of independent spirit.'));
    const linkOrder = ['Website', 'Mastodon', 'Bluesky', 'Twitter', 'GitHub'];
    for (const block of html.matchAll(/<div\b[^>]*class="[^"]*\bbuilder-links\b[^"]*"[^>]*>([\s\S]*?)<\/div>/g)) {
      const labels = [...block[1].matchAll(/<a\b[^>]*>([^<]+)/g)].map(match => match[1]);
      assert.ok(labels.length <= 5 && labels.every(label => linkOrder.includes(label)), 'use the five agreed builder link labels');
      assert.deepEqual(labels, [...labels].sort((a, b) => linkOrder.indexOf(a) - linkOrder.indexOf(b)), 'builder link order');
    }
    assertCanonicalURL(html, `${origin}/`, directory);
    assert.equal((html.match(/<h1\b/g) ?? []).length, 1);
    assert.equal((html.match(/<main\b/g) ?? []).length, 1);
    assert.equal(new Set(attributes(html, 'id')).size, attributes(html, 'id').length);
    const cards = html.match(/<article\b[^>]*>[\s\S]*?<\/article>/g) ?? [];
    assert.equal(cards.length, approvedProjects.length, 'one card per contributing project');
    // Match Swift's stable Unicode ordering, independent of the runner's locale.
    const compare = (a, b) => Buffer.compare(Buffer.from(a.normalize('NFC')), Buffer.from(b.normalize('NFC')));
    const ordered = [...approvedProjects].sort((a, b) => compare(a.name.toLowerCase(), b.name.toLowerCase()) || compare(a.id, b.id));
    assert.deepEqual(cards.map(card => attributes(card, 'id')[0]), ordered.map(project => project.id ? `project-${project.id}` : null));
    for (const project of approvedProjects) {
      const card = cards.find(card => attributes(card, 'id')[0] === `project-${project.id}`);
      const maker = indies.find(indie => indie.id === project.indieID);
      assert.equal((card.match(/class="[^"]*\bbuilder-row\b/g) ?? []).length, maker.people?.length ?? 1);
      assert.ok(attributes(card, 'href').includes(project.websiteURL));
    }
    for (const resource of resources) assert.ok(attributes(html, 'href').includes(resource.url), resource.name);
    assert.ok(!html.includes('indieappcatalog.com') && !html.includes('9to5mac.com'), 'only selected discovery resources');
    assert.ok(!html.includes('brand-sponsored'), 'showcase wordmark');
    assert.ok(!html.includes('offer-terms.mjs') && !html.includes('product-card-benefits'), 'project-focused content');
    assert.equal(html.includes('noindex, nofollow'), preview);
    for (const path of ['/', '/participate/indies/', '/terms/']) {
      assert.ok(attributes(html, 'href').includes(sponsoredOrigin + path), `footer ${path}`);
    }
    const footer = html.match(/<footer\b[\s\S]*?<nav\b[^>]*>([\s\S]*?)<\/nav>/)?.[1];
    assert.ok(footer, 'showcase footer navigation');
    assert.deepEqual(attributes(footer, 'href'), [sponsoredOrigin + '/', sponsoredOrigin + '/terms/']);
    const sitemap = await read(`${directory}/sitemap.xml`);
    assert.deepEqual([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(match => match[1]), [`${origin}/`]);
    const image = await readFile(join(website, directory, 'social-preview.png'));
    assert.equal(image.readUInt32BE(16), 1200);
    assert.equal(image.readUInt32BE(20), 630);
    assert.notDeepEqual(image, await readFile(join(website, sponsoredDirectory, 'social-preview.png')), 'site-specific sharing artwork');
    if (!preview) {
      assert.equal((await read(`${directory}/CNAME`)).trim(), 'byindies.com');
      const readme = await read(`${directory}/README.md`);
      assert.match(readme, /^# By Indies$/m);
      assert.ok(readme.includes('https://github.com/dadederk/Sponsored-by-Indies'));
      assert.ok(readme.includes('https://sponsored.byindies.com/participate/'));
      assert.ok(readme.includes('](readme-banner.png)'));
      await stat(join(website, directory, '.nojekyll'));
    }
  });

  test(`${directory}: local assets and links between publications resolve, including bundle anchors`, async () => {
    const roots = new Map([[origin, directory], [sponsoredOrigin, sponsoredDirectory]]);
    for (const current of roots.values()) {
      const files = (await readdir(join(website, current), {recursive:true})).filter(file => file.endsWith('.html'));
      const currentOrigin = [...roots].find(([, value]) => value === current)[0];
      for (const file of files) {
        const html = await read(`${current}/${file}`);
        for (const target of [...attributes(html, 'href'), ...attributes(html, 'src')]) {
          if (!target) continue;
          const url = new URL(target.replaceAll('&amp;', '&'), `${currentOrigin}/${file}`);
          if (!roots.has(url.origin)) continue;
          let path = join(website, roots.get(url.origin), decodeURIComponent(url.pathname));
          const info = await stat(path).catch(() => assert.fail(`${current}/${file}: missing ${target}`));
          if (info.isDirectory()) path = join(path, 'index.html');
          await stat(path);
          if (url.hash && path.endsWith('.html')) {
            const destination = await readFile(path, 'utf8');
            assert.ok(attributes(destination, 'id').includes(decodeURIComponent(url.hash.slice(1))), `${file}: missing ${target}`);
          }
        }
      }
    }
  });
}
