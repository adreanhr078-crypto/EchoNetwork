import { test, expect } from 'playwright/test';

// Isolated room presentation only. No authentication, receipt, or full journey claim.
test('director baseline: record the actual rendered room and loaded assets', async ({ page }, testInfo) => {
  test.setTimeout(90000);
  const errors: string[] = [];
  const assets = new Map<string, number>();
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (!/\.glb(?:\?|$)/.test(response.url())) return;
    const declaredBytes = Number(response.headers()['content-length'] ?? 0);
    assets.set(response.url(), Number.isFinite(declaredBytes) ? declaredBytes : 0);
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
    const echo = scene?.getObjectByName('echo-player');
    let loadedEcho = false;
    echo?.traverse((object: any) => {
      if (object.isSkinnedMesh) loadedEcho = true;
    });
    return loadedEcho;
  }), { timeout: 60000 }).toBe(true);
  await expect.poll(() => page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__?.scene;
    const capsule = scene?.getObjectByName('sector11-wake-capsule');
    let meshCount = 0;
    capsule?.traverse((object: any) => {
      if (object.isMesh) meshCount += 1;
    });
    return !!capsule && meshCount >= 4;
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

  // The debug bridge changes presentation only; it cannot move Echo or grant
  // progress. Use it for a deterministic visual audit of the capsule behind him.
  await page.evaluate(() => (window as any).__11_11_SCENE__.setCameraYaw(Math.PI));
  await page.waitForTimeout(350);
  await capture('wake-capsule');
  await page.evaluate(() => (window as any).__11_11_SCENE__.setCameraYaw(0));
  await page.waitForTimeout(350);

  // Real input, not teleporting or granting any progression.
  const start = await echoPosition();
  expect(start).not.toBeNull();
  await page.keyboard.down('w');
  await page.waitForTimeout(150);
  const accelerationSample = await echoPosition();
  await page.waitForTimeout(850);
  const cruiseSample = await echoPosition();
  await page.keyboard.up('w');
  await page.evaluate(() => new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  }));
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

  const placeEchoNear = async (x: number, z: number) => {
    await page.evaluate(({ x: nextX, z: nextZ }) => {
      const player = (window as any).__11_11_SCENE__?.scene
        ?.getObjectByName('echo-player');
      if (!player) throw new Error('Echo player is unavailable.');
      player.position.x = nextX;
      player.position.z = nextZ;
    }, { x, z });
  };

  // Inspect the real evidence loop in the rendered room. Teleporting is used
  // only to remove pathfinding time from this presentation audit; interaction,
  // focus feedback and narrative state still run through production code.
  await placeEchoNear(3.8, 2.55);
  await expect(page.locator('.gameplay-interaction-prompt')).toContainText('الساعة');
  await capture('clock-focus');
  await page.keyboard.press('e');
  await expect(page.getByRole('dialog')).toContainText('الساعة المتوقفة');
  await page.getByRole('button', { name: 'متابعة' }).click();

  await placeEchoNear(6.8, 7.35);
  await expect(page.locator('.gameplay-interaction-prompt')).toContainText('الصورة');
  await capture('photo-focus');
  await page.keyboard.press('e');
  await expect(page.getByRole('dialog')).toContainText('الصورة الممزقة');
  await expect(page.getByRole('dialog')).toContainText('MEMORY FRAGMENT');
  const rendered = await page.evaluate(() => {
    const bridge = (window as any).__11_11_SCENE__;
    const names: string[] = [];
    bridge.scene.traverse((object: any) => { if (object.name) names.push(object.name); });
    return { names, renderer: bridge.gl.info.render, geometries: bridge.gl.info.memory.geometries,
      textures: bridge.gl.info.memory.textures, hud: document.querySelector('.gameplay-hud')?.textContent };
  });
  const runtimeResources = await page.evaluate(() => performance
    .getEntriesByType('resource')
    .filter((entry) => /\.glb(?:\?|$)/.test(entry.name))
    .map((entry) => {
      const resource = entry as PerformanceResourceTiming;
      return {
        name: resource.name,
        durationMs: Math.round(resource.duration),
        transferBytes: resource.transferSize,
        decodedBytes: resource.decodedBodySize,
      };
    }));
  const glbUrls = [...assets.keys()];
  const declaredGlbBytes = [...assets.values()].reduce((sum, bytes) => sum + bytes, 0);
  await testInfo.attach('observation', { body: JSON.stringify({ assets: Object.fromEntries(assets), declaredGlbBytes, runtimeResources, errors, rendered }, null, 2), contentType: 'application/json' });
  expect(glbUrls.some(url => url.endsWith('/assets/characters/echo.runtime.glb'))).toBe(true);
  expect(glbUrls.some(url => url.endsWith('/assets/props/tripo_monster.glb'))).toBe(false);
  expect(declaredGlbBytes).toBeLessThanOrEqual(6 * 1024 * 1024);
  expect(errors).toEqual([]);
});

test('cinematic handoff opens the real capsule and returns control through the authored wake beat', async ({ page }, testInfo) => {
  test.setTimeout(120000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/e2e/fixtures/gameplay-room.html?cinematic&tutorial');

  const video = page.locator('.cinematic-director-overlay video');
  await expect(video).toBeVisible({ timeout: 30000 });
  await expect(page.locator('[data-cinematic-active="true"]')).toBeVisible();
  await expect.poll(() => page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__?.scene;
    return !!scene?.getObjectByName('CAPSULE_DOOR_HINGE');
  }), { timeout: 30000 }).toBe(true);

  const closedRotation = await page.evaluate(() => (
    (window as any).__11_11_SCENE__.scene
      .getObjectByName('CAPSULE_DOOR_HINGE').rotation.y
  ));
  await video.evaluate((node: HTMLVideoElement) => {
    node.dispatchEvent(new Event('ended'));
  });
  await expect(page.getByText('CONSCIOUSNESS LINK // 01')).toBeVisible();
  await page.waitForTimeout(250);
  const insidePosition = await page.evaluate(() => (
    (window as any).__11_11_SCENE__.scene
      .getObjectByName('echo-player').position.z
  ));
  expect(insidePosition).toBeGreaterThan(13.8);
  const wakeHipOffset = await page.evaluate(() => {
    const scene = (window as any).__11_11_SCENE__.scene;
    const echo = scene.getObjectByName('echo-player');
    let hips: any = null;
    echo.traverse((object: any) => {
      if (!hips && /(?:mixamorig)?hips$/i.test(object.name)) hips = object;
    });
    if (!hips) return null;
    const hipWorld = hips.position.clone();
    const echoWorld = echo.position.clone();
    hips.getWorldPosition(hipWorld);
    echo.getWorldPosition(echoWorld);
    return Math.abs(hipWorld.x - echoWorld.x);
  });
  expect(wakeHipOffset).not.toBeNull();
  expect(wakeHipOffset!).toBeLessThan(0.12);
  const colorBridge = await page.locator('.opening-cinematic-overlay').evaluate((overlay) => {
    const style = getComputedStyle(overlay, '::before');
    return {
      animationName: style.animationName,
      backgroundImage: style.backgroundImage,
    };
  });
  expect(colorBridge.animationName).toContain('opening-cinematic-color-bridge');
  expect(colorBridge.backgroundImage).toContain('133, 102, 194');
  await page.screenshot({ path: testInfo.outputPath('awakening-color-bridge.png') });
  await page.waitForTimeout(1100);
  const openingRotation = await page.evaluate(() => (
    (window as any).__11_11_SCENE__.scene
      .getObjectByName('CAPSULE_DOOR_HINGE').rotation.y
  ));
  expect(Math.abs(openingRotation - closedRotation)).toBeGreaterThan(0.15);
  await page.screenshot({ path: testInfo.outputPath('awakening-handoff.png') });

  await expect(page.getByRole('dialog', { name: 'تحكم بـEcho' })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('.cinematic-director-overlay')).toHaveCount(0);
  await expect(page.getByText('CONSCIOUSNESS LINK // 01')).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => (
    (window as any).__11_11_SCENE__.scene
      .getObjectByName('echo-player').position.z
  ))).toBeCloseTo(9.5, 1);
  expect(errors).toEqual([]);
});

test('reduced-motion awakening preserves orientation and reaches the same control gate', async ({ page }, testInfo) => {
  test.setTimeout(90000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/e2e/fixtures/gameplay-room.html?cinematic&tutorial&reduced');

  await expect(page.locator('[data-cinematic-active="true"]')).toBeVisible({ timeout: 30000 });
  await expect(page.locator('.cinematic-director-overlay video')).toHaveCount(0);
  await expect(page.getByRole('dialog', { name: 'تحكم بـEcho' })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('.cinematic-director-overlay')).toHaveCount(0);
  await expect(page.getByText('CONSCIOUSNESS LINK // 01')).toHaveCount(0);
  await page.waitForTimeout(450);
  await page.screenshot({ path: testInfo.outputPath('reduced-control-handoff.png') });
  await expect.poll(() => page.evaluate(() => (
    (window as any).__11_11_SCENE__?.scene
      ?.getObjectByName('echo-player')?.position.z
  ))).toBeCloseTo(9.5, 1);
  expect(errors).toEqual([]);
});
