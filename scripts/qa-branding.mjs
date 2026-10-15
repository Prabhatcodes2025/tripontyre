import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = normalize(join(process.cwd(), 'dist'));
const output = normalize(join(process.cwd(), '.qa', 'branding'));
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
};

const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url || '/', 'http://local').pathname);
    const requested = normalize(join(root, pathname === '/' ? 'index.html' : pathname.replace(/^\//, '')));
    const path = requested.startsWith(root) && extname(requested) ? requested : join(root, 'index.html');
    const body = await readFile(path).catch(() => readFile(join(root, 'index.html')));
    response.writeHead(200, {
      'content-type': mime[extname(path)] || 'application/octet-stream',
      'cache-control': 'no-store',
    });
    response.end(body);
  } catch (error) {
    response.writeHead(500, { 'content-type': 'text/plain' });
    response.end(String(error));
  }
});

await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const { port } = server.address();
const baseURL = `http://127.0.0.1:${port}`;
await mkdir(output, { recursive: true });

const viewports = [
  { width: 320, height: 720 },
  { width: 375, height: 812 },
  { width: 390, height: 844 },
  { width: 768, height: 1024 },
  { width: 1024, height: 768 },
  { width: 1440, height: 1000 },
];

const inspectBrands = page => page.locator('[data-brand-lockup]:visible').evaluateAll(elements => elements.map((element, index) => {
  const box = node => {
    const rect = node?.getBoundingClientRect();
    return rect ? { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height } : null;
  };
  const rootBox = box(element);
  const mark = box(element.querySelector('.official-brand__mark'));
  const wordmark = box(element.querySelector('.official-brand__wordmark img'));
  const legal = box(element.querySelector('.official-brand__legal'));
  const identity = box(element.querySelector('.official-brand__identity'));
  const epsilon = 0.75;
  return {
    index,
    parent: element.parentElement?.className || '',
    label: element.getAttribute('aria-label'),
    root: rootBox,
    mark,
    wordmark,
    legal,
    identity,
    wordmarkLegalGap: wordmark && legal ? Number((legal.top - wordmark.bottom).toFixed(2)) : null,
    wordmarkLegalOverlap: Boolean(wordmark && legal && legal.top < wordmark.bottom - epsilon),
    markIdentityOverlap: Boolean(mark && identity && identity.left < mark.right - epsilon),
    clippedByRoot: Boolean(rootBox && [mark, identity].filter(Boolean).some(child => child.left < rootBox.left - epsilon || child.right > rootBox.right + epsilon || child.top < rootBox.top - epsilon || child.bottom > rootBox.bottom + epsilon)),
  };
}));

const inspectPage = async page => ({
  overflow: await page.evaluate(() => Math.max(0, document.documentElement.scrollWidth - window.innerWidth)),
  brands: await inspectBrands(page),
  brokenImages: await page.locator('img').evaluateAll(images => images.filter(image => image.complete && image.naturalWidth === 0).length),
});

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const report = { generatedAt: new Date().toISOString(), viewports: [], inaccessible: [] };

try {
  for (const viewport of viewports) {
    const page = await browser.newPage({ viewport });
    const consoleErrors = [];
    page.on('console', message => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });

    await page.goto(baseURL, { waitUntil: 'networkidle' });
    const normal = await inspectPage(page);
    const headerBefore = await page.locator('.header').evaluate(element => {
      const rect = element.getBoundingClientRect();
      return { top: rect.top, height: rect.height, sticky: getComputedStyle(element).position };
    });
    await page.screenshot({ path: join(output, `after-${viewport.width}-normal.png`) });

    await page.locator('.hero-brand-logo').waitFor({ state: 'visible', timeout: 8000 });
    const heroSignature = await inspectPage(page);
    await page.screenshot({ path: join(output, `after-${viewport.width}-hero-brand.png`) });

    await page.evaluate(() => window.scrollTo(0, 650));
    await page.waitForTimeout(300);
    const scrolled = await inspectPage(page);
    const headerAfter = await page.locator('.header').evaluate(element => {
      const rect = element.getBoundingClientRect();
      return { top: rect.top, height: rect.height, scrolled: element.classList.contains('scrolled') };
    });
    await page.screenshot({ path: join(output, `after-${viewport.width}-scrolled.png`) });

    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(150);
    const footer = await inspectPage(page);

    let mobileMenu = null;
    if (viewport.width <= 900) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.locator('.menu-button').click();
      mobileMenu = {
        expanded: await page.locator('.menu-button').getAttribute('aria-expanded'),
        visible: await page.locator('.nav.open').isVisible(),
        overflow: await page.evaluate(() => Math.max(0, document.documentElement.scrollWidth - window.innerWidth)),
      };
      await page.screenshot({ path: join(output, `after-${viewport.width}-menu.png`) });
    }

    await page.goto(`${baseURL}/login`, { waitUntil: 'networkidle' });
    const auth = await inspectPage(page);
    await page.screenshot({ path: join(output, `after-${viewport.width}-auth.png`), fullPage: true });

    await page.goto(`${baseURL}/auth/callback?error=qa`, { waitUntil: 'networkidle' });
    const authCallback = await inspectPage(page);

    report.viewports.push({
      width: viewport.width,
      normal,
      heroSignature,
      scrolled,
      footer,
      auth,
      authCallback,
      headerBefore,
      headerAfter,
      mobileMenu,
      consoleErrors,
    });
    await page.close();
  }

  const accessPage = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await accessPage.goto(`${baseURL}/admin`, { waitUntil: 'networkidle' });
  report.inaccessible.push({
    surface: 'authenticated admin shell',
    blockerVisible: await accessPage.getByText('Secure service awaiting configuration').isVisible(),
    brandCount: await accessPage.locator('[data-brand-lockup]').count(),
  });
  await accessPage.goto(`${baseURL}/account`, { waitUntil: 'networkidle' });
  report.inaccessible.push({
    surface: 'authenticated customer dashboard',
    redirectedTo: new URL(accessPage.url()).pathname,
    brandCount: await accessPage.locator('[data-brand-lockup]').count(),
  });
  await accessPage.close();
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}

const failures = [];
for (const result of report.viewports) {
  for (const [surface, check] of Object.entries({ normal: result.normal, heroSignature: result.heroSignature, scrolled: result.scrolled, footer: result.footer, auth: result.auth, authCallback: result.authCallback })) {
    if (check.overflow > 0) failures.push(`${result.width}px ${surface}: ${check.overflow}px horizontal overflow`);
    if (check.brokenImages > 0) failures.push(`${result.width}px ${surface}: ${check.brokenImages} broken images`);
    for (const brand of check.brands) {
      if (brand.wordmarkLegalOverlap) failures.push(`${result.width}px ${surface} brand ${brand.index}: wordmark/legal overlap`);
      if (brand.markIdentityOverlap) failures.push(`${result.width}px ${surface} brand ${brand.index}: mark/identity overlap`);
      if (brand.clippedByRoot) failures.push(`${result.width}px ${surface} brand ${brand.index}: clipped by lock-up root`);
    }
  }
  if (result.headerAfter.top !== 0 || !result.headerAfter.scrolled) failures.push(`${result.width}px: sticky/scrolled header failed`);
  if (result.headerBefore.height !== result.headerAfter.height) failures.push(`${result.width}px: header layout shifted while scrolling`);
  if (result.mobileMenu && (!result.mobileMenu.visible || result.mobileMenu.expanded !== 'true' || result.mobileMenu.overflow > 0)) failures.push(`${result.width}px: mobile menu failed`);
}

report.failures = failures;
report.passed = failures.length === 0;
await writeFile(join(output, 'report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ passed: report.passed, failures, viewports: report.viewports.map(item => ({ width: item.width, normalBrands: item.normal.brands.length, authBrands: item.auth.brands.length, normalOverflow: item.normal.overflow, headerHeight: item.headerBefore.height, mobileMenu: item.mobileMenu })) }, null, 2));
if (failures.length) process.exitCode = 1;
