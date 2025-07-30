// Helpers spécifiques pour FLB Solutions

/**
 * Gère tous les popups potentiels au chargement
 */
async function handleFLBPopups(page) {
  // Attendre un peu pour que les popups se chargent
  await page.waitForTimeout(2000);
  
  // 1. Popup GDPR/Cookies
  const cookiePopup = page.locator('.amgdprcookie-groups-modal:visible, .gdpr-cookie-modal:visible');
  if (await cookiePopup.count() > 0) {
    try {
      // Chercher bouton accepter
      const acceptBtn = page.locator('button:has-text("Accepter"), button:has-text("Accept all"), .amgdprcookie-button.-allow');
      if (await acceptBtn.isVisible({ timeout: 1000 })) {
        await acceptBtn.click();
        console.log('✓ Cookies GDPR acceptés');
        await page.waitForTimeout(500);
      }
    } catch (e) {
      console.log('⚠️ Popup cookies présent mais non géré');
    }
  }
  
  // 2. Popup de connexion (modal générique)
  const loginModal = page.locator('.modal-popup:visible, .authentication-popup:visible');
  if (await loginModal.count() > 0) {
    try {
      // Fermer avec X ou bouton fermer
      const closeBtn = loginModal.locator('.action-close, [aria-label*="Close"], [aria-label*="Fermer"], button:has-text("×")');
      if (await closeBtn.isVisible({ timeout: 1000 })) {
        await closeBtn.click();
        console.log('✓ Popup connexion fermé');
        await page.waitForTimeout(500);
      }
    } catch (e) {
      // Essayer ESC si bouton fermer non trouvé
      await page.keyboard.press('Escape');
      console.log('✓ Popup fermé avec ESC');
    }
  }
  
  // 3. Attendre stabilisation finale
  await page.waitForLoadState('networkidle');
}

/**
 * Se connecte au site FLB
 */
async function loginToFLB(page, email, password, dadhriNumber = '') {
  // Aller à la page de connexion
  await page.goto('https://www.flbsolutions.com/customer/account/login/');
  await page.waitForLoadState('networkidle');
  
  // Gérer les popups potentiels avant de remplir le formulaire
  await handleFLBPopups(page);
  
  // Remplir le formulaire avec les 3 champs
  await page.locator('input[name="login[email]"], #email').first().fill(email);
  
  // Champ numéro Dadhri (optionnel)
  const dadhriField = page.locator('input[name="dadhri-number"], #dadhri-number');
  if (await dadhriField.isVisible({ timeout: 1000 }) && dadhriNumber) {
    await dadhriField.fill(dadhriNumber);
    console.log('✓ Numéro Dadhri renseigné');
  }
  
  // Champ mot de passe
  await page.locator('input[name="login[password]"], input[name="password"], #pass').first().fill(password);
  
  // Soumettre
  await page.locator('#send2, button[type="submit"]').first().click();
  
  // Attendre redirection ou popup
  await page.waitForTimeout(2000);
  
  // Gérer le popup de sélection livraison/ramassage
  await handleDeliveryPopup(page);
  
  // Vérifier qu'on est bien connecté
  await page.waitForURL(/customer\/account/, { timeout: 10000 });
  console.log('✓ Connexion réussie');
}

/**
 * Gère le popup de sélection de livraison/ramassage après connexion
 */
async function handleDeliveryPopup(page) {
  try {
    // Attendre que le popup apparaisse
    const deliveryModal = page.locator('.modal-popup:visible, [data-role="modal"]:visible').filter({ hasText: /livraison|ramassage|delivery|pickup/i });
    
    if (await deliveryModal.isVisible({ timeout: 3000 })) {
      console.log('📦 Popup de livraison détecté');
      
      // Option 1: Sélectionner une date dans ~2 jours
      const dateSelector = page.locator('select[name*="date"], input[type="date"], .delivery-date-selector');
      if (await dateSelector.isVisible({ timeout: 1000 })) {
        // Calculer date dans 2 jours
        const futureDate = new Date();
        futureDate.setDate(futureDate.getDate() + 2);
        const dateString = futureDate.toISOString().split('T')[0]; // Format YYYY-MM-DD
        
        if (await dateSelector.getAttribute('type') === 'date') {
          await dateSelector.fill(dateString);
        } else {
          // Si c'est un select, choisir la 3ème option (souvent ~2 jours)
          await dateSelector.selectOption({ index: 2 });
        }
        console.log(`✓ Date sélectionnée : ${dateString}`);
      }
      
      // Option 2: Sélectionner un créneau horaire
      const timeSlot = page.locator('.time-slot, input[name*="time"], select[name*="time"]').first();
      if (await timeSlot.isVisible({ timeout: 1000 })) {
        // Choisir le premier créneau disponible
        if (await timeSlot.getAttribute('type') === 'radio') {
          await timeSlot.click();
        } else {
          await timeSlot.selectOption({ index: 0 });
        }
        console.log('✓ Créneau horaire sélectionné');
      }
      
      // Option 3: Choisir entre livraison et ramassage
      const deliveryOption = page.locator('input[value*="delivery"], input[value*="livraison"], label:has-text("Livraison")').first();
      const pickupOption = page.locator('input[value*="pickup"], input[value*="ramassage"], label:has-text("Ramassage")').first();
      
      if (await deliveryOption.isVisible({ timeout: 1000 })) {
        await deliveryOption.click();
        console.log('✓ Option livraison sélectionnée');
      } else if (await pickupOption.isVisible({ timeout: 1000 })) {
        await pickupOption.click();
        console.log('✓ Option ramassage sélectionnée');
      }
      
      // Valider le choix
      const confirmBtn = page.locator('button:has-text("Confirmer"), button:has-text("Valider"), button:has-text("Continuer"), button[type="submit"]').filter({ hasText: /confirm|valider|continuer|submit/i });
      if (await confirmBtn.isVisible({ timeout: 1000 })) {
        await confirmBtn.click();
        console.log('✓ Choix de livraison confirmé');
        await page.waitForTimeout(1000);
      }
    }
  } catch (e) {
    console.log('ℹ️ Pas de popup de livraison ou déjà configuré');
  }
}

/**
 * Vérifie si l'utilisateur est connecté
 */
async function isLoggedIn(page) {
  const welcomeText = page.locator('.customer-welcome .logged-in');
  return await welcomeText.isVisible({ timeout: 2000 }).catch(() => false);
}

/**
 * Configuration des intercepteurs de requêtes
 */
async function setupRequestInterceptors(page) {
  // Bloquer certaines ressources non essentielles pour accélérer les tests
  await page.route('**/*.{png,jpg,jpeg,gif,webp,svg}', route => {
    // Autoriser seulement les images du domaine principal
    if (route.request().url().includes('flbsolutions.com')) {
      route.continue();
    } else {
      route.abort();
    }
  });
  
  // Bloquer les analytics
  await page.route('**/google-analytics.com/**', route => route.abort());
  await page.route('**/googletagmanager.com/**', route => route.abort());
}

module.exports = {
  handleFLBPopups,
  loginToFLB,
  isLoggedIn,
  setupRequestInterceptors,
  handleDeliveryPopup
};