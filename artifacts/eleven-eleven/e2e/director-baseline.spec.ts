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
  await page.addInitScript(() => {
    const AudioContextConstructor = window.AudioContext
      ?? (window as any).webkitAudioContext;
    if (!AudioContextConstructor) return;
    const originalCreateBufferSource = AudioContextConstructor.prototype.createBufferSource;
    (window as any).__11_11_FOOTSTEP_SOURCES__ = 0;
    AudioContextConstructor.prototype.createBufferSource = function createBufferSource() {
      (window as any).__11_11_FOOTSTEP_SOURCES__ += 1;
      return originalCreateBufferSource.call(this);
    };
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
  const echoPosition = () => page.evaluate(() => {
    const player = (window as any).__11_11_SCENE__?.scene
      ?.getObjectByName('echo-player');
    return player ? { x: player.position.x, z: player.position.z } : null;
  });
  const distance = (a: { x: number; z: number }, b: { x: number; z: number }) => (
    Math.hypot(a.x - b.x, a.z - b.z)
  );
  await capture('room-entry');
  // Real input, not teleporting or granting any progression.
  const start = await echoPosition();
  expect(start).not.toBeNull();
  await page.keyboard.down('w');
  await page.waitForTimeout(150);
  const accelerationSample = await echoPosition();
  await page.waitForTimeout(850);
  const cruiseSample = await echoPosition();
  await page.keyboard.up('w');
  await page.waitForTimeout(80);
  const releaseSample = await echoPosition();
  await page.waitForTimeout(420);
  const settledSample = await echoPosition();
  expect(distance(start!, accelerationSample!)).toBeGreaterThan(0.01);
  expect(distance(accelerationSample!, cruiseSample!)).toBeGreaterThan(0.5);
  expect(distance(cruiseSample!, releaseSample!)).toBeGreaterThan(0.001);
  expect(distance(releaseSample!, settledSample!)).toBeLessThan(0.2);
  expect(await page.evaluate(() => (window as any).__11_11_FOOTSTEP_SOURCES__)).toBeGreaterThan(0);
  const cameraState = await page.evaluate(() => {
    const camera = (window as any).__11_11_SCENE__?.camera;
    return camera ? {
      x: camera.position.x,
      y: camera.position.y,
      z: camera.position.z,
    } : null;
  });
  expect(cameraState).not.toBeNull();
  for (const value of Object.values(cameraState!)) expect(Number.isFinite(value)).toBe(true);
  expect(cameraState!.x).toBeGreaterThanOrEqual(-4.5);
  expect(cameraState!.x).toBeLessThanOrEqual(4.7);
  expect(cameraState!.y).toBeGreaterThanOrEqual(0.45);
  expect(cameraState!.y).toBeLessThanOrEqual(5.75);
  expect(cameraState!.z).toBeGreaterThanOrEqual(-14);
  expect(cameraState!.z).toBeLessThanOrEqual(16);
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
