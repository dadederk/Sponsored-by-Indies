import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { attributes, assertCanonicalURL } from './Support/output-checks.mjs';

const website = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const publicURL = new URL(process.env.PUBLIC_SITE_URL ?? 'https://sponsored.example.org');
assert.equal(publicURL.protocol, 'https:', 'PUBLIC_SITE_URL must use HTTPS.');
assert.equal(publicURL.pathname, '/', 'PUBLIC_SITE_URL must be a site root.');
assert.ok(!publicURL.search && !publicURL.hash && !publicURL.username && !publicURL.password,
  'PUBLIC_SITE_URL must not include credentials, a query or a fragment.');

for (const [directory, origin, preview] of [
  ['Build', 'http://localhost:8000', true],
  ['BuildPublic', publicURL.origin, false]
]) {
  test(`${directory}: metadata, landmarks, local links and anchors`, async () => {
    const root = join(website, directory);
    const files = (await readdir(root, { recursive: true })).filter(file => file.endsWith('.html'));
    assert.ok(files.length >= 8, 'Generate both site outputs before running these checks.');
    const pages = new Map();
    const expectedSitemap = new Set();
    const imagePath = new URL('/social-preview.png', origin);
    const png = await readFile(join(root, 'social-preview.png'));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', 'sharing image is a PNG');
    assert.equal(png.readUInt32BE(16), 1200, 'sharing image width');
    assert.equal(png.readUInt32BE(20), 630, 'sharing image height');
    for (const [name, width, height] of [
      ['social-avatar.png', 1024, 1024], ['social-banner.png', 1500, 500],
      ['favicon-32.png', 32, 32], ['apple-touch-icon.png', 180, 180]
    ]) {
      const asset = await readFile(join(root, name));
      assert.equal(asset.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', `${name}: PNG format`);
      assert.equal(asset.readUInt32BE(16), width, `${name}: width`);
      assert.equal(asset.readUInt32BE(20), height, `${name}: height`);
    }
    const ico = await readFile(join(root, 'favicon.ico'));
    assert.equal(ico.subarray(0, 6).toString('hex'), '000001000100', 'ICO directory header');
    assert.equal(ico.readUInt32LE(18), 22, 'ICO representation offset');
    assert.deepEqual(ico.subarray(22), await readFile(join(root, 'favicon-32.png')), 'ICO contains current artwork');
    for (const file of files) {
      const html = await readFile(join(root, file), 'utf8');
      const version = html.match(/design-tokens\.css\?v=([a-f0-9]+)/)?.[1];
      assert.ok(version, `${file}: versioned brand assets`);
      imagePath.search = new URLSearchParams({v: version}).toString();
      const imageURL = imagePath.href;
      for (const path of ['favicon.ico', 'favicon-shared-imprint-01.svg', 'apple-touch-icon.png']) {
        assert.ok(html.includes(`href="/${path}?v=${version}"`), `${file}: current ${path}`);
      }
      assert.match(html, /name="theme-color" content="#[a-fA-F0-9]{6}"/, `${file}: browser theme colour`);
      pages.set(join(root, file), html);
      assert.equal((html.match(/<main\b/g) ?? []).length, 1, `${file}: one main landmark`);
      assert.equal((html.match(/<h1\b/g) ?? []).length, 1, `${file}: one H1`);
      const ids = attributes(html, 'id');
      assert.equal(new Set(ids).size, ids.length, `${file}: unique IDs`);
      assert.ok(ids.includes('main'), `${file}: skip-link target`);
      assert.match(html, /<title>[^<]+<\/title>/, `${file}: title`);
      assert.match(html, /<meta[^>]+name="description"[^>]+content="[^"]+"/, `${file}: description`);
      const route = '/' + file.replace(/(^|\/)index\.html$/, '$1');
      const isAccess = route.endsWith('/access/');
      const permanentLinks = [...html.matchAll(/<a\b[^>]*href="([^"]+)"[^>]*>Permanent link to /g)];
      const isHub = /^\/conferences\/[^/]+\/$/.test(route) && permanentLinks.length > 0;
      const canonical = new URL(isHub ? permanentLinks[0][1] : route, origin).href;
      assertCanonicalURL(html, canonical, file);
      const robots = [...html.matchAll(/<meta\b[^>]*>/g)].map(m => m[0])
        .filter(tag => attributes(tag, 'name').includes('robots'));
      assert.deepEqual(robots.map(tag => attributes(tag, 'content')[0]),
        preview ? ['noindex, nofollow'] : isAccess ? ['noindex, follow'] : [], `${file}: indexing policy`);
      for (const [attribute, name, expected] of [
        ['property', 'og:url', canonical], ['property', 'og:image', imageURL], ['name', 'twitter:image', imageURL]
      ]) {
        const tags = [...html.matchAll(/<meta\b[^>]*>/g)].map(m => m[0])
          .filter(tag => attributes(tag, attribute).includes(name));
        assert.deepEqual(tags.map(tag => attributes(tag, 'content')[0]), [expected], `${file}: ${name}`);
      }
      if (!isAccess && !isHub) expectedSitemap.add(canonical);
    }
    const sitemap = await readFile(join(root, 'sitemap.xml'), 'utf8');
    const locations = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1]);
    assert.equal(locations.length, new Set(locations).size, 'unique sitemap URLs');
    assert.deepEqual(new Set(locations), expectedSitemap, 'only indexable canonical pages in sitemap');
    const robotsText = await readFile(join(root, 'robots.txt'), 'utf8');
    assert.ok(robotsText.includes(`Sitemap: ${origin}/sitemap.xml`), 'robots sitemap uses the build origin');
    for (const [file, html] of pages) {
      for (const target of [...attributes(html, 'href'), ...attributes(html, 'src')]) {
        if (!target || /^(?:[a-z]+:|\/\/)/i.test(target)) continue;
        const url = new URL(target.replaceAll('&amp;', '&'), origin + '/' + file.slice(root.length + 1));
        let path = join(root, decodeURIComponent(url.pathname));
        const info = await stat(path).catch(() => assert.fail(`${file}: missing target ${target}`));
        if (info.isDirectory()) path = join(path, 'index.html');
        await stat(path).catch(() => assert.fail(`${file}: missing page ${target}`));
        if (url.hash && pages.has(path)) {
          assert.ok(attributes(pages.get(path), 'id').includes(decodeURIComponent(url.hash.slice(1))), `${file}: missing anchor ${target}`);
        }
      }
    }
  });
}
