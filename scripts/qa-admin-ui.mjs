import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = normalize(join(process.cwd(), '.qa/admin-dist'));
const mime = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.webp':'image/webp', '.svg':'image/svg+xml' };
const server = createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url || '/', 'http://local').pathname);
  const requested = normalize(join(root, pathname === '/' ? 'index.html' : pathname.replace(/^\//, '')));
  const path = requested.startsWith(root) && extname(requested) ? requested : join(root, 'index.html');
  const body = await readFile(path).catch(() => readFile(join(root, 'index.html')));
  response.writeHead(200, { 'content-type':mime[extname(path)] || 'application/octet-stream', 'cache-control':'no-store' });
  response.end(body);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const baseURL = `http://127.0.0.1:${address.port}`;
await mkdir('.qa/current', { recursive:true });

const now = Math.floor(Date.now() / 1000);
const jwt = `${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({aud:'authenticated',role:'authenticated',sub:'11111111-1111-4111-8111-111111111111',exp:now+3600})).toString('base64url')}.qa`;
const session = { access_token:jwt, token_type:'bearer', expires_in:3600, expires_at:now+3600, refresh_token:'qa-refresh', user:{ id:'11111111-1111-4111-8111-111111111111', aud:'authenticated', role:'authenticated', email:'qa-admin@example.invalid', app_metadata:{provider:'email'}, user_metadata:{}, created_at:new Date().toISOString() } };

const fixtures = {
  bookings:[{id:'b1',reference:'MYT-QA-001',travel_date:'2026-12-15',total_amount:125000,balance_amount:25000,currency:'INR',booking_status:'confirmed',payment_status:'success',created_at:new Date().toISOString(),tour_packages:{title:'Kashmir Winter'}}],
  leads:[{id:'l1',name:'QA Traveller',destination:'Kashmir',status:'qualified',created_at:new Date().toISOString()}],
  payments:[{id:'p1',status:'success',amount:100000}],
  package_availability:[{id:'a1',travel_date:'2026-12-15',capacity:18,reserved:7,status:'open',tour_packages:{title:'Kashmir Winter'}}],
  tour_packages:[{id:'pkg1',title:'Kashmir Winter',slug:'kashmir-winter',category:'domestic',is_upcoming:true,published:true,hero_image:'/travel/mountain-river-bridge.webp',updated_at:new Date().toISOString()}],
};

async function installBackendFixture(context) {
  await context.addInitScript(({session}) => localStorage.setItem('sb-test-auth-token', JSON.stringify(session)), {session});
  await context.route('https://test.supabase.co/**', async route => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.pathname.includes('/rest/v1/profiles') && url.searchParams.get('select') === 'role') return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({role:'admin'})});
    const table = url.pathname.split('/rest/v1/')[1]?.split('?')[0];
    if (table) {
      if (request.method() === 'HEAD') return route.fulfill({status:200,headers:{'content-range':'0-0/3','content-type':'application/json'},body:''});
      return route.fulfill({status:200,headers:{'content-range':'0-0/1','content-type':'application/json'},body:JSON.stringify(fixtures[table] || [])});
    }
    return route.fulfill({status:200,contentType:'application/json',body:'{}'});
  });
}

const browser = await chromium.launch({ channel:'chrome', headless:true });
const report = {};
try {
  const desktop = await browser.newContext({ viewport:{width:1440,height:1000} });
  await installBackendFixture(desktop);
  const page = await desktop.newPage();
  page.setDefaultTimeout(10000);
  await page.goto(`${baseURL}/admin`, { waitUntil:'networkidle' });
  await page.getByRole('heading', {name:'Dashboard'}).waitFor();
  report.dashboard = { visible:true, overflow:await page.evaluate(() => document.documentElement.scrollWidth-window.innerWidth) };
  await page.screenshot({path:'.qa/current/admin-dashboard-desktop.png',fullPage:false});
  await page.getByRole('button', {name:/^Packages/}).click();
  await page.getByText('Kashmir Winter').waitFor();
  await page.getByRole('button', {name:'New record'}).click();
  const upload = page.locator('input[type=file][name=hero_image]');
  await upload.setInputFiles('public/travel/tulip-garden.webp');
  await page.locator('.admin-media-previews img').waitFor();
  report.packageEditor = { previewVisible:await page.locator('.admin-media-previews img').isVisible(), accepts:await upload.getAttribute('accept'), overflow:await page.evaluate(() => document.documentElement.scrollWidth-window.innerWidth) };
  await page.screenshot({path:'.qa/current/admin-package-editor-desktop.png',fullPage:false});
  await desktop.close();

  const mobile = await browser.newContext({ viewport:{width:390,height:844} });
  await installBackendFixture(mobile);
  const mobilePage = await mobile.newPage();
  mobilePage.setDefaultTimeout(10000);
  await mobilePage.goto(`${baseURL}/admin`, {waitUntil:'networkidle'});
  await mobilePage.getByRole('heading', {name:'Dashboard'}).waitFor();
  await mobilePage.getByRole('button', {name:'Toggle admin navigation'}).click();
  report.mobile = { navigationVisible:await mobilePage.getByRole('navigation', {name:'Admin navigation'}).isVisible(), overflow:await mobilePage.evaluate(() => document.documentElement.scrollWidth-window.innerWidth) };
  await mobilePage.screenshot({path:'.qa/current/admin-dashboard-mobile.png',fullPage:false});
  await mobile.close();
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
await writeFile('.qa/current/admin-report.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
