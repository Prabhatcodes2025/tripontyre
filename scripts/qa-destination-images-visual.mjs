import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const slugs = [
  'ayodhya-kashi-prayagraj-gaya-bodh-gaya','azerbaijan','bangalore-mysore-kodagu',
  'bhutan','bijapur-hampi-badami-aihole-pattadakkal-chitradurga','chikmagalur',
  'delhi-agra-jaipur-amritsar-wagah-border','gujarat','hampi','hyderabad','jog-falls',
  'kerala-full','kolkata','malaysia-singapore','matheran','meghalaya','mumbai',
  'munnar-thekkady-kochi-alappuzha-kumarakom-varkala-kovalam',
  'munnar-thekkady-vagamon-kochi-athirappalli','nepal','odisha','ooty-mysore',
  'rameswaram-dhanushkodi-madurai-kodaikanal','sikkim-darjeeling','sri-lanka',
  'vagamon','valparai-athirappalli','wayanad','kashmir-kargil','kasol',
  'kullu-manali-kasol','ladakh','bali-nusa-penida','indonesia','gokarna','lakshadweep',
];
const root = normalize(join(process.cwd(), 'dist'));
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.webp':'image/webp', '.svg':'image/svg+xml' };
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url || '/', 'http://local').pathname);
    const requested = normalize(join(root, pathname === '/' ? 'index.html' : pathname.replace(/^\//, '')));
    const file = requested.startsWith(root) && extname(requested) ? requested : join(root, 'index.html');
    const body = await readFile(file).catch(() => readFile(join(root, 'index.html')));
    response.writeHead(200, { 'content-type':mime[extname(file)] || 'application/octet-stream', 'cache-control':'no-store' });
    response.end(body);
  } catch (error) {
    response.writeHead(500, { 'content-type':'text/plain' });
    response.end(String(error));
  }
});

await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const { port } = server.address();
const browser = await chromium.launch({ channel:'chrome', headless:true });
const failures = [];
const results = [];
try {
  for (const viewport of [{name:'mobile-390',width:390,height:844},{name:'desktop-1440',width:1440,height:1000}]) {
    const page = await browser.newPage({ viewport });
    await page.goto(`http://127.0.0.1:${port}/packages`, { waitUntil:'networkidle', timeout:120000 });
    const cards = [];
    for (const slug of slugs) {
      const card = page.locator(`a.catalog-card[href="/packages/${slug}"]`);
      if (await card.count() !== 1) { failures.push(`${viewport.name} ${slug}: package card not found`); continue; }
      const image = card.locator('img');
      await card.scrollIntoViewIfNeeded();
      await image.evaluate(node => node.complete ? undefined : new Promise(resolve => {
        node.addEventListener('load', resolve, { once:true });
        node.addEventListener('error', resolve, { once:true });
      }));
      const state = await image.evaluate(node => ({ src:node.currentSrc || node.src, loaded:node.complete && node.naturalWidth > 0 }));
      cards.push({ slug, ...state });
      if (!state.loaded) failures.push(`${viewport.name} ${slug}: image failed to load (${state.src})`);
    }
    if (new Set(cards.map(card => card.src)).size !== cards.length) failures.push(`${viewport.name}: replacement URLs are not unique`);
    const overflow = await page.evaluate(() => Math.max(0, document.documentElement.scrollWidth - window.innerWidth));
    if (overflow) failures.push(`${viewport.name}: ${overflow}px horizontal overflow`);
    await page.goto(`http://127.0.0.1:${port}/packages/wayanad`, { waitUntil:'networkidle', timeout:120000 });
    if (await page.locator('.photo-credit a').count() !== 2) failures.push(`${viewport.name}: image attribution is not visible on package detail`);
    results.push({ viewport:viewport.name, cards:cards.length, overflow });
    await page.close();
  }
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}

console.log(JSON.stringify({ passed:failures.length===0, results, failures }, null, 2));
if (failures.length) process.exitCode = 1;
