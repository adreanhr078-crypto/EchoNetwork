const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  try {
    console.log("Launching Edge...");
    const browser = await chromium.launchPersistentContext(
      "C:\\\\Users\\\\yasmo\\\\AppData\\\\Local\\\\Microsoft\\\\Edge\\\\User Data",
      {
        executablePath: "C:\\\\Program Files (x86)\\\\Microsoft\\\\Edge\\\\Application\\\\msedge.exe",
        headless: false,
        channel: 'msedge'
      }
    );
    const page = await browser.newPage();
    await page.goto('https://www.tripo3d.ai/app');
    console.log("Navigated to Tripo. You can now generate models!");
  } catch (e) {
    console.error("Error launching Edge: ", e.message);
    if (e.message.includes('lock')) {
      console.log("Edge is currently open. Please close Edge so the script can use your profile.");
    }
  }
})();
