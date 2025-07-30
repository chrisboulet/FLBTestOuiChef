const { test, expect } = require('@playwright/test');
const { handleFLBPopups, setupRequestInterceptors } = require('../helpers/flb-helpers');

test.describe('FLB Smoke Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Optimiser les requêtes pour les tests
    await setupRequestInterceptors(page);
    
    // Naviguer vers la page d'accueil
    await page.goto('https://www.flbsolutions.com');
    
    // Gérer tous les popups potentiels
    await handleFLBPopups(page);
  });

  test('Homepage loads correctly', async ({ page }) => {
    // Vérifier le titre
    await expect(page).toHaveTitle(/FLB solutions alimentaires/);
    
    // Vérifier éléments critiques - sélecteurs robustes pour éviter multiples correspondances
    const catalogueLink = page.locator('nav a').filter({ hasText: /^Catalogue$/i })
      .or(page.locator('.navigation a').filter({ hasText: /^Catalogue$/i }))
      .or(page.locator('a[href*="tous-les-produits"]'));
    await expect(catalogueLink.first()).toBeVisible();
    
    const accountLink = page.locator('a').filter({ hasText: /^Mon compte$/i })
      .or(page.locator('.customer-menu a, .header-links a').filter({ hasText: 'Mon compte' }))
      .or(page.locator('a[href*="customer/account"]'));
    await expect(accountLink.first()).toBeVisible();
  });

  test('Catalog page accessible', async ({ page }) => {
    await page.goto('/fr/tous-les-produits.html');
    
    // Vérifier présence de titre de page - sélecteur robuste
    const pageTitle = page.locator('h1, .page-title, .category-title').filter({ hasText: /produits/i })
      .or(page.locator('[data-ui-id="page-title-wrapper"]'))
      .or(page.locator('.breadcrumbs').filter({ hasText: /produits/i }));
    await expect(pageTitle.first()).toBeVisible();
    
    // Vérifier qu'il y a des produits listés avec sélecteur spécifique
    const products = page.locator('.product-item, .product-wrapper, [data-container="product"]');
    await expect(products.first()).toBeVisible();
  });

  test('Login functionality available', async ({ page }) => {
    await page.goto('/customer/account/login/');
    
    // Gérer les popups avant de vérifier les champs
    await handleFLBPopups(page);
    
    // Vérifier formulaire de connexion avec sélecteurs robustes
    const emailField = page.locator('form[data-role="email-with-possible-login"] input[name="login[email]"]')
      .or(page.locator('input[name="login[email]"]'))
      .or(page.locator('#email'));
    await expect(emailField.first()).toBeVisible();
    
    const passwordField = page.locator('form[data-role="email-with-possible-login"] input[name="login[password]"]')
      .or(page.locator('input[name="login[password]"]'))
      .or(page.locator('input[type="password"][name="password"]'));
    await expect(passwordField.first()).toBeVisible();
    
    const submitButton = page.locator('form[data-role="email-with-possible-login"] button[type="submit"]')
      .or(page.locator('#send2'))
      .or(page.locator('button[type="submit"]'));
    await expect(submitButton.first()).toBeVisible();
    
    // Vérifier champ Dadhri si présent
    const dadhriField = page.locator('input[name="dadhri-number"]');
    if (await dadhriField.isVisible({ timeout: 1000 })) {
      console.log('✓ Champ Dadhri trouvé');
    }
  });

  test('Search functionality works', async ({ page }) => {
    // Vérifier présence du champ de recherche
    const searchInput = page.locator('#search');
    await expect(searchInput).toBeVisible();
    
    // Effectuer une recherche
    await searchInput.fill('tomate');
    await searchInput.press('Enter');
    
    // Vérifier redirection vers résultats
    await expect(page).toHaveURL(/catalogsearch\/result/);
  });

  test('Cart functionality available', async ({ page }) => {
    // Vérifier icône panier
    const cartIcon = page.locator('.minicart-wrapper');
    await expect(cartIcon).toBeVisible();
    
    // Cliquer sur le panier
    await cartIcon.click();
    
    // Vérifier modal panier
    await expect(page.locator('#minicart-content-wrapper')).toBeVisible();
  });
});