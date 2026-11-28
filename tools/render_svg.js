// Convertit les SVG de art/sources en PNG 2x dans art/sprites.
// Usage : node tools/render_svg.js art/sources art/sprites (nécessite Node et Playwright).
// Sans Node : exporter chaque SVG en PNG à 200 % avec Inkscape donne le même résultat.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [src, out] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2 });
  for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg'))) {
    const svg = fs.readFileSync(path.join(src, f), 'utf8');
    const w = +svg.match(/width="(\d+)"/)[1], h = +svg.match(/height="(\d+)"/)[1];
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await page.locator('svg').screenshot({ path: path.join(out, f.replace('.svg', '.png')), omitBackground: true });
  }
  await browser.close();
})();
