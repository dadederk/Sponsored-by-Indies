import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile, readdir, stat} from 'node:fs/promises';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {attributes} from './Support/output-checks.mjs';

const website = fileURLToPath(new URL('../', import.meta.url));
for (const directory of ['Build', 'BuildPublic', 'BuildIndies', 'BuildIndiesPublic']) {
  test(`${directory}: generated artwork is grouped and sharing metadata resolves`, async () => {
    const root = join(website, directory);
    const entries = await readdir(root, {withFileTypes: true});
    const rootImages = entries.filter(entry => entry.isFile() && /\.(?:png|svg|ico)$/.test(entry.name))
      .map(entry => entry.name).sort();
    assert.deepEqual(rootImages, ['apple-touch-icon.png', 'favicon.ico'], 'only browser-discovery icons stay at the root');
    const artwork = (await readdir(join(root, 'assets'), {recursive: true})).filter(file => /\.(?:png|svg)$/.test(file));
    assert.ok(artwork.length > 0);
    for (const file of artwork) {
      assert.match(file, /^(?:brand|social|icons)\//, 'artwork has a purpose folder');
      assert.match(file, /(?:^|\/)[a-z0-9]+(?:-[a-z0-9]+)*\.(?:png|svg)$/, 'readable lowercase asset names');
    }
    const pages = (await readdir(root, {recursive: true})).filter(file => file.endsWith('.html'));
    for (const page of pages) {
      const html = await readFile(join(root, page), 'utf8');
      for (const tag of html.matchAll(/<meta\b[^>]*>/g)) {
        const isImage = attributes(tag[0], 'property').includes('og:image')
          || attributes(tag[0], 'name').includes('twitter:image');
        if (!isImage) continue;
        const url = new URL(attributes(tag[0], 'content')[0]);
        assert.match(url.pathname, /^\/assets\/(?:brand|social)\//, `${page}: grouped sharing artwork`);
        const image = await readFile(join(root, url.pathname));
        assert.equal(image.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', `${page}: sharing image exists`);
      }
    }
  });

  test(`${directory}: cards load bounded image copies with stable layout`, async () => {
    const root = join(website, directory);
    const pages = (await readdir(root, {recursive:true})).filter(file => file.endsWith('.html'));
    const checked = new Set();
    for (const page of pages) {
      const html = await readFile(join(root, page), 'utf8');
      for (const [tag] of html.matchAll(/<img\b[^>]*>/g)) {
        const src = attributes(tag, 'src')[0];
        if (!src || !/\/(app-icons|portraits)\//.test(src)) continue;
        assert.ok(src.startsWith('/optimized/'), `${page}: card must load the smaller copy`);
        const size = src.includes('/app-icons/') ? 64 : 56;
        assert.equal(attributes(tag, 'width')[0], String(size));
        assert.equal(attributes(tag, 'height')[0], String(size));
        assert.equal(attributes(tag, 'decoding')[0], 'async');
        assert.equal(attributes(tag, 'alt')[0], '', 'adjacent text describes the decorative artwork');
        if (src.includes('/portraits/')) assert.equal(attributes(tag, 'loading')[0], 'lazy');
        if (checked.has(src)) continue;
        checked.add(src);
        const target = join(root, src);
        assert.ok((await stat(target)).size > 0, `${src}: generated file exists`);
        if (src.endsWith('.png')) {
          const png = await readFile(target);
          assert.deepEqual([...png.subarray(0, 8)], [137,80,78,71,13,10,26,10]);
          assert.ok(Math.max(png.readUInt32BE(16), png.readUInt32BE(20)) <= size * 3, `${src}: at most 3× display size`);
        }
      }
    }
    assert.ok(checked.size > 0, 'rendered cards exercise the image pipeline');
  });
}
