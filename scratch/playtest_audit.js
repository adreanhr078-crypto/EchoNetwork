const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function runPlaytest() {
  console.log('--- STARTING AUDIT PLAYTEST ---');
  const browser = await chromium.launch({
    headless: true,
    args: ['--use-gl=angle', '--use-angle=default'] // Enable WebGL in headless
  });
  
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });

  const page = await context.newPage();
  const consoleLogs = [];
  const pageErrors = [];

  page.on('console', msg => consoleLogs.push({ type: msg.type(), text: msg.text() }));
  page.on('pageerror', err => pageErrors.push(err.message));

  // PASS 1: Main Menu
  console.log('Testing PASS 1: Main Menu...');
  await page.goto('http://127.0.0.1:5173/#/main-menu', { waitUntil: 'networkidle', timeout: 20000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(__dirname, 'snap_main_menu.png') });
  console.log('Main menu screenshot captured.');

  // PASS 2: Gameplay Route (#/play)
  console.log('Testing PASS 2: Direct Gameplay Route (#/play)...');
  await page.goto('http://127.0.0.1:5173/#/play', { waitUntil: 'networkidle', timeout: 20000 });
  await page.waitForTimeout(5000);
  await page.screenshot({ path: path.join(__dirname, 'snap_gameplay_play.png') });
  console.log('Gameplay #/play screenshot captured.');

  // PASS 3: Isolated 3D Room Fixture
  console.log('Testing PASS 3: Isolated Gameplay Room Fixture...');
  await page.goto('http://127.0.0.1:5173/e2e/fixtures/gameplay-room.html', { waitUntil: 'networkidle', timeout: 20000 });
  await page.waitForTimeout(6000); // Allow GLB models and shaders to compile
  await page.screenshot({ path: path.join(__dirname, 'snap_room_initial.png') });
  console.log('Isolated room initial screenshot captured.');

  // Inspect 3D scene state via SceneDebugBridge
  const sceneInfo = await page.evaluate(() => {
    const bridge = window.__11_11_SCENE__;
    if (!bridge) return { available: false };
    const objects = [];
    bridge.scene.traverse(obj => {
      if (obj.name || obj.isMesh) {
        objects.push({ name: obj.name, type: obj.type, visible: obj.visible });
      }
    });
    return {
      available: true,
      cameraPos: bridge.camera.position.toArray(),
      cameraRot: [bridge.camera.rotation.x, bridge.camera.rotation.y, bridge.camera.rotation.z],
      objectCount: objects.length,
      sampleObjects: objects.slice(0, 25)
    };
  });
  console.log('Scene Debug Info:', JSON.stringify(sceneInfo, null, 2));

  // Test Movement (Press W for 1.5 seconds)
  console.log('Testing Movement: Pressing W (Forward)...');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(1500);
  await page.keyboard.up('KeyW');
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(__dirname, 'snap_room_after_walk.png') });

  // Test Mobile Viewport
  console.log('Testing PASS 4: Mobile Landscape Viewport (844x390)...');
  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(__dirname, 'snap_room_mobile.png') });

  console.log('Audit run complete. Checking logs and errors...');
  fs.writeFileSync(
    path.join(__dirname, 'playtest_audit_results.json'),
    JSON.stringify({ consoleLogs, pageErrors, sceneInfo }, null, 2)
  );

  await browser.close();
  console.log('--- PLAYTEST COMPLETE ---');
}

runPlaytest().catch(err => {
  console.error('Playtest Error:', err);
  process.exit(1);
});
