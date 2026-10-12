// Gera o PDF a partir de out/manual.html usando o Chromium do Playwright
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
(async () => {
  const base = process.argv[2], out = process.argv[3];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + base + 'out/manual.html', { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.pdf({ path: out, format: 'A4', printBackground: true, preferCSSPageSize: true,
    displayHeaderFooter: true,
    headerTemplate: '<div style="font-family:sans-serif;font-size:7px;color:#999;width:100%;padding:0 15mm 0 18mm;margin-top:5mm;display:flex;justify-content:space-between"><span>GURGEL BR-800 · Manual de Serviços (1989) · versão redigida</span></div>',
    footerTemplate: '<div style="font-family:sans-serif;font-size:7px;color:#bbb;width:100%;padding:0 15mm 0 18mm;margin-bottom:3mm;text-align:left">PDF <span class="pageNumber"></span>/<span class="totalPages"></span></div>' });
  await browser.close();
})();
