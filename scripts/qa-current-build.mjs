import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = normalize(join(process.cwd(), 'dist'));
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.webp':'image/webp', '.svg':'image/svg+xml' };
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url || '/', 'http://local').pathname);
    const requested = normalize(join(root, pathname === '/' ? 'index.html' : pathname.replace(/^\//, '')));
    const path = requested.startsWith(root) && extname(requested) ? requested : join(root, 'index.html');
    const body = await readFile(path).catch(() => readFile(join(root, 'index.html')));
    response.writeHead(200, { 'content-type': mime[extname(path)] || 'application/octet-stream', 'cache-control':'no-store' });
    response.end(body);
  } catch (error) {
    response.writeHead(500, { 'content-type':'text/plain' });
    response.end(String(error));
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const baseURL = `http://127.0.0.1:${address.port}`;
await mkdir('.qa/current', { recursive:true });

const browser = await chromium.launch({ channel:'chrome', headless:true });
const report = { pages:[], hero:[], contact:[], admin:null };
try {
  for (const viewport of [{name:'mobile',width:390,height:844},{name:'desktop',width:1440,height:1000}]) {
    const page = await browser.newPage({ viewport });
    const consoleErrors = [];
    page.on('console', message => { if (message.type() === 'error') consoleErrors.push(message.text()); });
    await page.goto(baseURL, { waitUntil:'networkidle' });
    await page.waitForFunction(() => document.querySelector('.montage-meta b')?.textContent === 'Tulip Gardens, Kashmir', null, { timeout:14000 });
    const heroImage = await page.locator('.montage-frame img').evaluate(image => ({ complete:image.complete, naturalWidth:image.naturalWidth, naturalHeight:image.naturalHeight, src:image.getAttribute('src') }));
    const tulipCaption = await page.locator('.montage-meta').innerText();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    await page.screenshot({ path:`.qa/current/fifth-hero-${viewport.name}.png`, fullPage:false });
    await page.waitForFunction(() => document.querySelector('.montage-meta b')?.textContent === 'A street of your own', null, { timeout:5000 });
    const streetImage = await page.locator('.montage-frame img').getAttribute('src');
    await page.waitForFunction(() => document.querySelector('.montage-meta b')?.textContent === 'Wild horizons', null, { timeout:5000 });
    const treeImage = await page.locator('.montage-frame img').getAttribute('src');
    const logo = await page.locator('.header .official-brand').evaluate(element => ({
      label:element.getAttribute('aria-label'),
      legal:element.querySelector('.official-brand__legal')?.textContent,
      markVisible:Boolean(element.querySelector('.official-brand__mark img')?.getBoundingClientRect().width),
      wordmarkVisible:Boolean(element.querySelector('.official-brand__wordmark img')?.getBoundingClientRect().width),
    }));
    report.hero.push({ viewport:viewport.name, heroImage, tulipCaption, streetImage, treeImage, logo, overflow, consoleErrors:[...consoleErrors] });
    for (const route of ['/packages','/destinations','/gallery','/journal','/events','/testimonials','/awards']) {
      await page.goto(`${baseURL}${route}`, { waitUntil:'networkidle' });
      report.pages.push({ viewport:viewport.name, route, overflow:await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth), brokenImages:await page.locator('img').evaluateAll(images => images.filter(image => image.complete && image.naturalWidth === 0).length) });
    }
    await page.goto(`${baseURL}/contact`, { waitUntil:'networkidle' });
    const contactText = await page.locator('.contact-details').innerText();
    report.contact.push({ viewport:viewport.name, hasCorporate:contactText.includes('Mahipalpur, Delhi - 110037') && contactText.includes('7592999111'), hasKozhikode:contactText.includes('Sky Tower, Major Road Junction, Kozhikode') && contactText.includes('7592883311'), hasCities:['Bengaluru','Hyderabad','Mumbai'].every(city=>contactText.includes(city)), confirmedEmail:contactText.includes('infomytripontravel@gmail.com'), emailMailto:await page.locator('a[href="mailto:infomytripontravel@gmail.com"]').count(), overflow:await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth) });
    await page.close();
  }
  const page = await browser.newPage({ viewport:{width:1440,height:1000} });
  await page.goto(`${baseURL}/admin`, { waitUntil:'networkidle' });
  report.admin = { configuredBlocker:await page.getByText('Secure service awaiting configuration').isVisible(), overflow:await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth) };
  await page.screenshot({ path:'.qa/current/admin-unconfigured.png', fullPage:false });
  await page.close();
  const imagePage = await browser.newPage({ viewport:{width:900,height:675} });
  await imagePage.goto(`${baseURL}/travel/tulip-garden.webp`, { waitUntil:'load' });
  await imagePage.screenshot({ path:'.qa/current/fifth-hero-asset.png', fullPage:false });
  await imagePage.close();
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
await writeFile('.qa/current/report.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
