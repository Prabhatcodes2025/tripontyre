import { chromium } from 'file:///C:/Users/gauta/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';

const baseURL=process.env.QA_BASE_URL||'http://127.0.0.1:4173';
const viewports=[
  {name:'360',width:360,height:800},{name:'390',width:390,height:844},{name:'768',width:768,height:900},
  {name:'1024',width:1024,height:900},{name:'1440',width:1440,height:1000},
];
await mkdir('.qa',{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true});
const results=[];
for(const viewport of viewports){
  const page=await browser.newPage({viewport});
  const consoleErrors=[];
  page.on('console',message=>{if(message.type()==='error')consoleErrors.push(message.text())});
  await page.goto(baseURL,{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(500);
  const homeOverflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  const logoVisible=await page.locator('.header .official-brand__wordmark img').isVisible();
  await page.screenshot({path:`.qa/home-${viewport.name}.png`,fullPage:false});
  await page.goto(`${baseURL}/packages`,{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(300);
  const catalogueCount=await page.locator('.filter-result').textContent();
  const upcomingCount=await page.locator('.upcoming-strip>a').count();
  const packageOverflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  await page.screenshot({path:`.qa/packages-${viewport.name}.png`,fullPage:false});
  results.push({viewport:viewport.name,logoVisible,homeOverflow,packageOverflow,catalogueCount,upcomingCount,consoleErrors});
  await page.close();
}
const page=await browser.newPage({viewport:{width:390,height:844}});
await page.goto(baseURL,{waitUntil:'domcontentloaded'});
await page.locator('.menu-button').click();
await page.locator('.nav-dropdown>a').click();
const mobileAllDestinations=await page.locator('.mega-all').isVisible();
await page.goto(`${baseURL}/packages/not-a-real-trip`,{waitUntil:'domcontentloaded'});
const package404=await page.getByText('Journey not found.').isVisible();
await page.goto(`${baseURL}/destinations/not-a-real-place`,{waitUntil:'domcontentloaded'});
const destination404=await page.getByText('Destination not found.').isVisible();
await page.goto(baseURL,{waitUntil:'domcontentloaded'});
await page.waitForTimeout(3700);
const heroOfficialLogo=await page.locator('.hero-brand-logo .official-brand__wordmark img').isVisible();
const europeMention=(await page.locator('body').innerText()).toUpperCase().includes('EUROPE');
const report={results,mobileAllDestinations,package404,destination404,heroOfficialLogo,europeMention};
await writeFile('.qa/report.json',JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
await browser.close();
