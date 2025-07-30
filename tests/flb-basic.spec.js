  const { test, expect } = require('@playwright/test');

  test('FLB Homepage', async ({ page }) => {
    await page.goto('https://www.flbsolutions.com');
    // Titre réel : "FLB solutions alimentaires - distributeur alimentaire au Québec"
    await expect(page).toHaveTitle(/FLB solutions alimentaires/);
  });
