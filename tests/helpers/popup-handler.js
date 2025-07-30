// Helper pour gérer les popups récurrents FLB Solutions

async function handlePopups(page) {
  // 1. Popup de cookies
  try {
    // Sélecteurs possibles pour accepter les cookies
    const cookieSelectors = [
      'button:has-text("Accepter")',
      'button:has-text("Accept")',
      'button:has-text("J\'accepte")',
      '#accept-cookies',
      '.cookie-accept',
      '[data-cookie-accept]'
    ];
    
    for (const selector of cookieSelectors) {
      const button = page.locator(selector).first();
      if (await button.isVisible({ timeout: 2000 })) {
        await button.click();
        console.log('✓ Cookies acceptés via:', selector);
        break;
      }
    }
  } catch (e) {
    // Pas de popup cookies
  }

  // 2. Popup de connexion
  try {
    // Sélecteurs possibles pour fermer le popup
    const closeSelectors = [
      '[aria-label="Fermer"]',
      '[aria-label="Close"]',
      'button:has-text("Fermer")',
      'button:has-text("×")',
      '.modal-close',
      '.popup-close',
      '.close-button',
      '[data-dismiss="modal"]'
    ];
    
    for (const selector of closeSelectors) {
      const button = page.locator(selector).first();
      if (await button.isVisible({ timeout: 2000 })) {
        await button.click();
        console.log('✓ Popup fermé via:', selector);
        break;
      }
    }
  } catch (e) {
    // Pas de popup connexion
  }

  // 3. Attendre stabilisation
  await page.waitForLoadState('networkidle');
}

// Alternative : Se connecter si nécessaire
async function loginIfNeeded(page, email, password) {
  try {
    // Vérifier si on est déjà connecté
    if (await page.locator('text=Mon compte').isVisible()) {
      const accountText = await page.locator('.customer-welcome').textContent();
      if (accountText && accountText.includes('Bienvenue')) {
        console.log('✓ Déjà connecté');
        return;
      }
    }

    // Si popup de connexion présent, se connecter
    const emailInput = page.locator('#email-modal, #email');
    const passInput = page.locator('#pass-modal, #pass');
    
    if (await emailInput.isVisible({ timeout: 2000 })) {
      await emailInput.fill(email);
      await passInput.fill(password);
      await page.locator('button[type="submit"]').click();
      await page.waitForLoadState('networkidle');
      console.log('✓ Connexion réussie');
    }
  } catch (e) {
    console.log('ℹ Connexion non requise ou échouée');
  }
}

module.exports = { handlePopups, loginIfNeeded };