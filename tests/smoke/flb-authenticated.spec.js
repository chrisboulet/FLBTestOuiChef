const { test, expect } = require('@playwright/test');
const { handleFLBPopups, loginToFLB, setupRequestInterceptors } = require('../helpers/flb-helpers');

test.describe('FLB Tests Authentifiés', () => {
  // Credentials de test
  const TEST_EMAIL = process.env.FLB_TEST_EMAIL || 'cboulet@flbsolutions.com';
  const TEST_PASSWORD = process.env.FLB_TEST_PASSWORD || 'password123';
  const TEST_DADHRI = process.env.FLB_TEST_DADHRI || 'BOULETC';

  test.beforeEach(async ({ page }) => {
    // Optimiser les requêtes
    await setupRequestInterceptors(page);
    
    // Se connecter directement avec les 3 paramètres
    await loginToFLB(page, TEST_EMAIL, TEST_PASSWORD, TEST_DADHRI);
    
    // Note: loginToFLB gère déjà le popup de livraison
  });

  test('Prix affichés après connexion', async ({ page }) => {
    await page.goto('/fr/tous-les-produits.html');
    
    // Vérifier que les prix sont visibles
    const priceElement = page.locator('.price').first();
    await expect(priceElement).toBeVisible();
    
    // Vérifier format prix (ex: "12,95 $")
    const priceText = await priceElement.textContent();
    expect(priceText).toMatch(/\d+,\d{2}\s*\$/);
  });

  test('Ajout au panier fonctionne', async ({ page }) => {
    await page.goto('/fr/tous-les-produits.html');
    
    // Cliquer sur un produit
    await page.locator('.product-item').first().click();
    
    // Attendre page produit
    await page.waitForLoadState('networkidle');
    
    // Ajuster quantité et ajouter au panier
    const qtyInput = page.locator('#qty');
    if (await qtyInput.isVisible()) {
      await qtyInput.fill('2');
    }
    
    await page.locator('#product-addtocart-button').click();
    
    // Vérifier message de succès ou compteur panier
    const successMessage = page.locator('.message-success');
    const cartCounter = page.locator('.counter-number');
    
    await expect(successMessage.or(cartCounter)).toBeVisible({ timeout: 10000 });
  });

  test('Accès Mon Compte', async ({ page }) => {
    // Cliquer sur Mon compte - sélecteur plus spécifique
    await page.locator('a:has-text("Mon compte"), .customer-menu a:has-text("Mon compte"), .header-links a:has-text("Mon compte")').first().click();
    
    // Vérifier qu'on est sur le dashboard
    await expect(page).toHaveURL(/customer\/account/);
    await expect(page.locator('.page-title:has-text("Tableau de bord"), h1:has-text("Tableau de bord"), .dashboard-title:has-text("Tableau de bord")').first()).toBeVisible();
  });
});