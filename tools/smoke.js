// Opens the live site in headless Chrome, prints console errors and screenshots (base64).
const puppeteer = require('puppeteer-core');
const base = process.env.SITE || 'https://www774475437-svg.github.io/sanad/';
const shots = (process.env.SHOTS || '').split('|').filter(Boolean);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=swiftshader'],
  });
  for (const spec of shots) {
    const [name, query, waitS, wheel] = spec.split('~');
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 1 });
    page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) console.log('CONSOLE', name, m.type(), m.text().slice(0, 500)); });
    page.on('pageerror', (e) => console.log('PAGEERROR', name, String(e).slice(0, 800)));
    page.on('requestfailed', (r) => console.log('REQFAILED', name, r.url().slice(0, 200), r.failure() && r.failure().errorText));
    page.on('response', (r) => { if (r.status() >= 400) console.log('HTTP', r.status(), r.url().slice(0, 200)); });
    const url = base + (query || '') + (query ? '&' : '?') + 'nocache=' + Date.now();
    console.log('OPEN', name, url);
    await page.goto(url, { waitUntil: 'load', timeout: 120000 });
    await sleep(1000 * Number(waitS || 30));
    if (wheel) { await page.mouse.move(195, 400); await page.mouse.wheel({ deltaY: Number(wheel) }); await sleep(1500); }
    const boot = await page.evaluate(() => { const b = document.getElementById('sanad-boot'); return b ? b.innerText : 'GONE'; });
    console.log('BOOT', name, JSON.stringify(boot));
    const buf = await page.screenshot({ type: 'jpeg', quality: 55 });
    const b64 = Buffer.from(buf).toString('base64');
    console.log('SHOT ' + name + ' BEGIN');
    for (let i = 0; i < b64.length; i += 200) console.log('B64 ' + b64.slice(i, i + 200));
    console.log('SHOT ' + name + ' END');
    await page.close();
  }
  await browser.close();
})().catch((e) => { console.log('FATAL', e); process.exit(1); });
