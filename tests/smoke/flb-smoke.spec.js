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
    
    // Vérifier éléments critiques - utiliser des sélecteurs plus spécifiques
    await expect(page.locator('nav a:has-text("Catalogue"), .nav-link:has-text("Catalogue")').first()).toBeVisible();
    await expect(page.locator('a:has-text("Mon compte"), .customer-menu a:has-text("Mon compte")').first()).toBeVisible();
  });

  test('Catalog page accessible', async ({ page }) => {
    await page.goto('/fr/tous-les-produits.html');
    
    // Vérifier présence de produits - sélecteur plus spécifique
    await expect(page.locator('.page-title:has-text("produits"), h1:has-text("produits"), .category-title:has-text("produits")').first()).toBeVisible();
    
    // Vérifier qu'il y a des produits listés
    const products = page.locator('.product-item');
    await expect(products.first()).toBeVisible();
  });

  test('Login functionality available', async ({ page }) => {
    await page.goto('/customer/account/login/');
    
    // Gérer les popups avant de vérifier les champs
    await handleFLBPopups(page);
    
    // Vérifier formulaire de connexion avec les 3 champs
    await expect(page.locator('input[name="login[email]"], #email').first()).toBeVisible();
    await expect(page.locator('input[name="login[password]"], #pass').first()).toBeVisible();
    await expect(page.locator('#send2, form[data-role="email-with-possible-login"] button[type="submit"]').first()).toBeVisible();
    
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