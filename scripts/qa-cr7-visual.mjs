import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = normalize(join(process.cwd(), 'dist'));
const output = normalize(join(process.cwd(), '.qa', 'cr7'));
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.webp':'image/webp', '.svg':'image/svg+xml' };
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url || '/', 'http://local').pathname);
    const requested = normalize(join(root, pathname === '/' ? 'index.html' : pathname.replace(/^\//, '')));
    const path = requested.startsWith(root) && extname(requested) ? requested : join(root, 'index.html');
    const body = await readFile(path).catch(() => readFile(join(root, 'index.html')));
    response.writeHead(200, { 'content-type':mime[extname(path)] || 'application/octet-stream', 'cache-control':'no-store' });
    response.end(body);
  } catch (error) {
    response.writeHead(500, { 'content-type':'text/plain' });
    response.end(String(error));
  }
});

await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const { port } = server.address();
const baseURL = `http://127.0.0.1:${port}`;
await mkdir(output, { recursive:true });

const cases = [
  { title:'Bali - Nusa Penida', category:'International Tours', image:'nusa-penida.webp' },
  { title:'Agumbe', category:'Strangers Camp', image:'photo-1578378377576-2ed7065bdb87' },
  { title:'Ajanta - Ellora', category:'Domestic Tour', image:'photo-1620558601903-9f2441730121' },
  { title:'Andaman', category:'Domestic Tour', image:'photo-1767782843278-1cfc4acff2ff' },
];
const viewports = [{ name:'mobile-390', width:390, height:844 }, { name:'desktop-1440', width:1440, height:1000 }];
const browser = await chromium.launch({ channel:'chrome', headless:true });
const report = { viewports:[], failures:[] };

try {
  for (const viewport of viewports) {
    const page = await browser.newPage({ viewport });
    const consoleErrors = [];
    page.on('console', message => { if (message.type() === 'error') consoleErrors.push(message.text()); });
    await page.goto(`${baseURL}/packages`, { waitUntil:'networkidle' });
    const cards = [];
    for (const item of cases) {
      const heading = page.getByRole('heading', { name:item.title, exact:true });
      const card = heading.locator('xpath=ancestor::a[contains(@class,"catalog-card")]');
      await card.scrollIntoViewIfNeeded();
      await card.locator('img').evaluate(image => image.complete
        ? undefined
        : new Promise(resolve => {
          image.addEventListener('load', resolve, { once:true });
          image.addEventListener('error', resolve, { once:true });
        }));
      const observed = await card.evaluate(element => {
        const image = element.querySelector('img');
        return {
          title:element.querySelector('h3')?.textContent?.trim(),
          metadata:element.querySelector('small')?.textContent?.trim(),
          price:element.querySelector('.catalog-price')?.textContent?.trim(),
          image:image?.getAttribute('src'),
          imageLoaded:Boolean(image?.complete && image.naturalWidth > 0),
        };
      });
      cards.push(observed);
      if (!observed.metadata?.startsWith(item.category)) report.failures.push(`${viewport.name} ${item.title}: expected ${item.category}, got ${observed.metadata}`);
      if (!observed.metadata?.includes('Details coming soon') && !/\d+ day/.test(observed.metadata || '')) report.failures.push(`${viewport.name} ${item.title}: duration missing`);
      if (!observed.price) report.failures.push(`${viewport.name} ${item.title}: price/enquiry label missing`);
      if (!observed.image?.includes(item.image)) report.failures.push(`${viewport.name} ${item.title}: incorrect image ${observed.image}`);
      if (!observed.imageLoaded) report.failures.push(`${viewport.name} ${item.title}: image failed to load`);
      await card.screenshot({ path:join(output, `${viewport.name}-${item.title.toLowerCase().replace(/[^a-z0-9]+/g, '-')}.png`) });
    }
    if (new Set(cards.map(card => card.image)).size !== cards.length) report.failures.push(`${viewport.name}: corrected destination images are duplicated`);
    const overflow = await page.evaluate(() => Math.max(0, document.documentElement.scrollWidth - window.innerWidth));
    if (overflow) report.failures.push(`${viewport.name}: ${overflow}px horizontal overflow`);

    await page.goto(baseURL, { waitUntil:'networkidle' });
    const journeyCards = await page.locator('.journey-feature').evaluateAll(elements => elements.map(element => ({
      duration:element.querySelector('small')?.textContent?.trim(),
      price:element.querySelector('.journey-price')?.textContent?.trim(),
    })));
    if (!journeyCards.length || journeyCards.some(card => !card.duration || !card.price)) report.failures.push(`${viewport.name}: home package card duration or price missing`);

    report.viewports.push({ viewport:viewport.name, cards, journeyCards, overflow, consoleErrors });
    await page.close();
  }
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}

report.passed = report.failures.length === 0;
await writeFile(join(output, 'report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ passed:report.passed, failures:report.failures, viewports:report.viewports.map(item => ({ viewport:item.viewport, cardCount:item.cards.length, overflow:item.overflow, consoleErrors:item.consoleErrors })) }, null, 2));
if (!report.passed) process.exitCode = 1;
