const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BRAVE_PATH = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';

async function run() {
  const args = process.argv.slice(2);
  const command = args[0];
  const target = args[1];

  if (!command) {
    console.log('Usage: node brave-manager.js <command> [args]');
    console.log('Commands: tabs, switch, audit, screenshot, click, type, hover, scroll, html, eval');
    process.exit(1);
  }

  const browser = await puppeteer.connect({
    browserURL: 'http://127.0.0.1:9222',
  }).catch(async () => {
    return await puppeteer.launch({
      executablePath: BRAVE_PATH,
      headless: false,
      args: ['--remote-debugging-port=9222', '--user-data-dir=/tmp/brave-manager-profile']
    });
  });

  const pages = await browser.pages();
  let page = pages[0];

  // Set up monitoring if it's a new page
  const logs = [];
  const network = [];
  
  const setupPage = async (p) => {
    p.on('console', msg => logs.push(`[${msg.type()}] ${msg.text()}`));
    await p.setRequestInterception(true).catch(() => {});
    p.on('request', req => {
      network.push(`${req.method()} ${req.url()}`);
      req.continue().catch(() => {});
    });
  };

  try {
    if (command === 'tabs') {
      pages.forEach((p, i) => console.log(`[${i}] ${p.url()}`));
    } else if (command === 'switch') {
      const index = parseInt(target);
      page = pages[index] || pages[0];
      await page.bringToFront();
      console.log(`Switched to tab ${index}: ${page.url()}`);
    } else if (command === 'html') {
      const content = await page.content();
      console.log(content);
    } else if (command === 'type') {
      await page.type(target, args[2]);
      console.log(`Typed into ${target}`);
    } else if (command === 'hover') {
      await page.hover(target);
      console.log(`Hovered over ${target}`);
    } else if (command === 'scroll') {
      const dist = target === 'up' ? -500 : 500;
      await page.evaluate(d => window.scrollBy(0, d), dist);
      console.log(`Scrolled ${target}`);
    } else if (command === 'click') {
      await page.click(target);
      console.log(`Clicked ${target}`);
    } else if (command === 'audit') {
      await setupPage(page);
      if (target) await page.goto(target, { waitUntil: 'networkidle2' });
      console.log('\n--- BROWSER LOGS ---');
      logs.forEach(l => console.log(l));
      console.log('\n--- NETWORK ACTIVITY ---');
      network.slice(0, 20).forEach(n => console.log(n));
    } else if (command === 'screenshot') {
      if (target) await page.goto(target, { waitUntil: 'networkidle2' });
      await page.screenshot({ path: 'screenshot.png', fullPage: true });
      console.log('Screenshot saved to screenshot.png');
    } else if (command === 'eval') {
      const result = await page.evaluate(target);
      console.log(JSON.stringify(result, null, 2));
    }
  } catch (err) {
    console.error('ERROR:', err.message);
  } finally {
    if (command !== 'tabs') await new Promise(r => setTimeout(r, 1000));
    await browser.disconnect().catch(() => browser.close());
  }
}

run();