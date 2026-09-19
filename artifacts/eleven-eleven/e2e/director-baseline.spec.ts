import { test, expect } from 'playwright/test';

// Isolated room presentation only. No authentication, receipt, or full journey claim.
test('director baseline: record the actual rendered room and loaded assets', async ({ page }, testInfo) => {
  test.setTimeout(90000);
  const errors: string[] = [];
  const assets = new Set<string>();
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (/\.glb(?:\?|$)/.test(response.url())) assets.add(response.url());
  });
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/e2e/fixtures/gameplay-room.html');
  await expect(page.locator('[data-canvas-ready="true"]')).toBeVisible({ timeout: 60000 });
  await expect.poll(() => page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__?.scene;
    return !!scene?.getObjectByName('opening-room');
  }), { timeout: 60000 }).toBe(true);
  await expect.poll(() => page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__?.scene;
    return [
      'stopped-digital-clock',
      'torn-photograph',
      'opening-door-control',
    ].every(name => !!scene?.getObjectByName(name));
  }), { timeout: 60000 }).toBe(true);
  await expect.poll(() => page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__?.scene;
    let loadedEcho = false;
    scene?.traverse((object: any) => {
      if (object.isSkinnedMesh) loadedEcho = true;
    });
    return loadedEcho;
  }), { timeout: 60000 }).toBe(true);
  const capture = async (name: string) => {
    await page.screenshot({ path: testInfo.outputPath(`${name}.png`) });
  };
  await capture('room-entry');
  // Real input, not teleporting or granting any progression.
  await page.keyboard.down('w');
  await page.waitForTimeout(1800);
  await page.keyboard.up('w');
  await capture('after-walking');
  const rendered = await page.evaluate(() => {
    const bridge = (window as any).__11_11_SCENE__;
    const names: string[] = [];
    bridge.scene.traverse((object: any) => { if (object.name) names.push(object.name); });
    return { names, renderer: bridge.gl.info.render, geometries: bridge.gl.info.memory.geometries,
      textures: bridge.gl.info.memory.textures, hud: document.querySelector('.gameplay-hud')?.textContent };
  });
  await testInfo.attach('observation', { body: JSON.stringify({ assets: [...assets], errors, rendered }, null, 2), contentType: 'application/json' });
  expect(errors).toEqual([]);
});
