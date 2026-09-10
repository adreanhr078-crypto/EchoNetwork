import { test, expect } from 'playwright/test';

const fixture = '/e2e/fixtures/screen-break.html';
for (const locale of ['en', 'ar']) {
  for (const viewport of [{ width: 1440, height: 900 }, { width: 844, height: 390 }, { width: 390, height: 844 }]) {
    test(`${locale} ${viewport.width}: reduced motion stays modal and completes once`, async ({ page }) => {
      await page.setViewportSize(viewport);
      await page.goto(`${fixture}?reduced&locale=${locale}`);
      const launch = page.getByRole('button', { name: 'Open cinematic' });
      await launch.click();
      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();
      await expect(dialog.locator('video')).toHaveCount(0);
      expect(await dialog.evaluate(node => node.matches(':modal'))).toBe(true);
      for (let i = 0; i < 4; i++) {
        await page.keyboard.press('Tab');
        expect(await dialog.evaluate(node => node.contains(document.activeElement) || document.activeElement === document.body)).toBe(true);
      }
      const button = dialog.getByRole('button');
      const box = await button.boundingBox();
      expect(box!.height).toBeGreaterThanOrEqual(44);
      expect(box!.x).toBeGreaterThanOrEqual(0);
      expect(box!.x + box!.width).toBeLessThanOrEqual(viewport.width);
      await page.keyboard.press('Escape');
      await expect(dialog).toHaveCount(0);
      await expect(page.getByLabel('Completions')).toHaveText('1');
      await expect(launch).toBeFocused();
    });
  }
}

test('missing media remains recoverable and never completes automatically', async ({ page }) => {
  await page.goto(`${fixture}?missing&noFracture`);
  await page.getByRole('button', { name: 'Open cinematic' }).click();
  const retry = page.getByRole('button', { name: 'Reload cinematic' });
  await expect(retry).toBeVisible();
  await retry.click();
  await expect(retry).toBeVisible();
  await expect(page.getByLabel('Completions')).toHaveText('0');
  await page.getByRole('button', { name: 'Skip cinematic' }).click();
  await expect(page.getByLabel('Completions')).toHaveText('1');
});

test('real movie decodes muted, allows pause/resume, and finishes on ended', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${fixture}?noFracture`);
  await page.getByRole('button', { name: 'Open cinematic' }).click();
  const video = page.locator('video');
  await expect.poll(() => video.evaluate((node: HTMLVideoElement) => node.currentTime)).toBeGreaterThan(0);
  expect(await video.evaluate((node: HTMLVideoElement) => node.muted)).toBe(true);
  expect(await video.evaluate((node: HTMLVideoElement) => node.videoWidth)).toBe(1920);
  await video.evaluate((node: HTMLVideoElement) => node.pause());
  await page.getByRole('button', { name: 'Play cinematic' }).click();
  await expect.poll(() => video.evaluate((node: HTMLVideoElement) => node.paused)).toBe(false);
  await expect(page.getByLabel('Completions')).toHaveText('1', { timeout: 40000 });
  expect(errors).toEqual([]);
});
