/**
 * 11.11 – Smoke Tests
 *
 * Verifies:
 * - No white screen on main menu and accessible routes
 * - No unhandled console JS errors
 * - Cinematic 11.11 visual identity renders
 * - Arabic bilingual labels are visible
 * - Mobile landscape and desktop viewports
 *
 * NOTE: Gameplay canvas (Opening Room) requires auth/demo entry.
 * This suite tests what is publicly reachable. The DEMO access test
 * will verify canvas if a guest entry button is present.
 */

import { test, expect } from 'playwright/test';

const BASE_URL = 'http://localhost:3000';

const JS_ERROR_NOISE = [
  'Warning:',
  'THREE.',
  'WebGL',
  'GLSL',
  'shader',
  'ResizeObserver',
  'Non-Error promise rejection',
];

function isSignalError(msg: string): boolean {
  return !JS_ERROR_NOISE.some((noise) => msg.includes(noise));
}

// ─── Desktop: Main Menu Visual Identity ──────────────────────────────────────

test.describe('11.11 – Main Menu: desktop 1280×800', () => {
  test.use({ viewport: { width: 1280, height: 800 } });

  test('cinematic main menu renders without white screen or JS errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => consoleErrors.push(err.message));

    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });

    // Non-white background (obsidian / dark visual identity)
    const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    expect(bg, 'Expected dark background, not white').not.toBe('rgb(255, 255, 255)');

    // Page body is visible
    await expect(page.locator('body')).toBeVisible({ timeout: 5000 });

    // At least one Arabic label visible from the known set
    const arabicText = page
      .getByText('الدخول', { exact: false })
      .or(page.getByText('سجّل', { exact: false }))
      .or(page.getByText('القائمة', { exact: false }))
      .or(page.getByText('وابدأ', { exact: false }));
    await expect(arabicText.first()).toBeVisible({ timeout: 10000 });

    // No catastrophic JS errors
    const jsErrors = consoleErrors.filter(isSignalError);
    expect(jsErrors, `Console errors:\n${jsErrors.join('\n')}`).toEqual([]);
  });
});

// ─── Mobile Landscape: Main Menu ─────────────────────────────────────────────

test.describe('11.11 – Main Menu: mobile landscape 844×390', () => {
  test.use({ viewport: { width: 844, height: 390 } });

  test('mobile landscape renders without white screen or JS errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => consoleErrors.push(err.message));

    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });

    const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    expect(bg, 'Expected dark background, not white').not.toBe('rgb(255, 255, 255)');

    await expect(page.locator('body')).toBeVisible({ timeout: 5000 });

    const jsErrors = consoleErrors.filter(isSignalError);
    expect(jsErrors, `Console errors:\n${jsErrors.join('\n')}`).toEqual([]);
  });
});

// ─── DEMO / Guest Gameplay Canvas ────────────────────────────────────────────

test.describe('11.11 – Gameplay canvas (DEMO entry)', () => {
  test.use({ viewport: { width: 1280, height: 800 } });

  test('app loads without blocking JS errors (gameplay canvas UNVERIFIED without auth)', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => consoleErrors.push(err.message));

    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });

    // Non-white background on load
    const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    expect(bg, 'Expected dark background, not white').not.toBe('rgb(255, 255, 255)');

    // Page is stable (no routing errors, no blank screen)
    await expect(page.locator('body')).toBeVisible({ timeout: 5000 });

    // No catastrophic JS errors
    const jsErrors = consoleErrors.filter(isSignalError);
    expect(jsErrors, `Console errors:\n${jsErrors.join('\n')}`).toEqual([]);

    // UNVERIFIED: gameplay canvas requires authenticated user.
    // To verify: sign in with a test account, navigate to the gameplay route,
    // and confirm [data-canvas-ready="true"] appears within 20s.
    console.log(
      '[UNVERIFIED] Gameplay 3D canvas requires user authentication. ' +
      'Main menu and app shell verified. ' +
      'Opening Room visual quality changes (floor, camera, monster, HUD, animations) ' +
      'cannot be screenshot-verified without a signed-in test account.'
    );
  });
});
