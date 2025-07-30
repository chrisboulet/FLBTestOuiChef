const { test, expect } = require('@playwright/test');
const { handleFLBPopups, loginToFLB, setupRequestInterceptors } = require('../helpers/flb-helpers');
const { smartNavigate, smartClick, waitForElementReady } = require('../helpers/smart-waits');

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
    // Navigation intelligente vers catalogue
    await smartNavigate(page, '/fr/tous-les-produits.html', {
      waitForSelectors: ['.product-item'],
      timeout: 15000
    });
    
    // Cliquer sur premier produit avec attente intelligente
    await smartClick(page, '.product-item', {
      timeout: 10000,
      waitForResponse: true
    });
    
    // Attendre page produit stabilisée
    await waitForElementReady(page, '#product-addtocart-button', {
      action: 'clickable',
      timeout: 10000
    });
    
    // Ajuster quantité si champ présent
    try {
      const qtyInput = await waitForElementReady(page, '#qty', {
        timeout: 2000,
        retries: 1
      });
      await qtyInput.fill('2');
      console.log('✓ Quantité ajustée à 2');
    } catch (e) {
      console.log('ℹ️ Champ quantité non trouvé, utilise quantité par défaut');
    }
    
    // Ajouter au panier avec attente de réponse
    await smartClick(page, '#product-addtocart-button', {
      waitForResponse: true,
      responseTimeout: 10000
    });
    
    // Vérifier succès avec attente intelligente
    const successMessage = page.locator('.message-success, .messages .message-success');
    const cartCounter = page.locator('.counter-number, .minicart-wrapper .counter-number');
    
    await expect(successMessage.or(cartCounter)).toBeVisible({ timeout: 10000 });
    console.log('✓ Produit ajouté au panier avec succès');
  });

  test('Accès Mon Compte', async ({ page }) => {
    // Cliquer sur Mon compte - sélecteur plus spécifique
    await page.locator('a:has-text("Mon compte"), .customer-menu a:has-text("Mon compte"), .header-links a:has-text("Mon compte")').first().click();
    
    // Vérifier qu'on est sur le dashboard
    await expect(page).toHaveURL(/customer\/account/);
    await expect(page.locator('.page-title:has-text("Tableau de bord"), h1:has-text("Tableau de bord"), .dashboard-title:has-text("Tableau de bord")').first()).toBeVisible();
  });
});