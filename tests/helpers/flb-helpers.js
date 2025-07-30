// Helpers spécifiques pour FLB Solutions
const { smartNavigate, smartFill, smartClick, waitForElementReady } = require('./smart-waits');

/**
 * Gère tous les popups potentiels au chargement avec smart waits
 */
async function handleFLBPopups(page) {
  // Attendre la stabilisation initiale 
  await page.waitForLoadState('domcontentloaded');
  
  // 1. Gestion intelligente popup GDPR/Cookies avec retry pattern
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      // Détecter popup GDPR avec sélecteur robuste
      const cookiePopup = page.locator('.amgdprcookie-groups-modal, .gdpr-cookie-modal, [data-role="gdpr-modal"]')
        .filter({ hasText: /cookies|gdpr|consentement/i });
      
      if (await cookiePopup.isVisible({ timeout: 2000 })) {
        // Chercher bouton accepter avec multiple stratégies
        const acceptBtn = page.locator('button').filter({ hasText: /accepter|accept/i })
          .or(page.locator('.amgdprcookie-button.-allow, .accept-all, .consent-accept'))
          .or(page.locator('[data-role="accept-all"], [data-action="accept"]'));
        
        if (await acceptBtn.first().isVisible({ timeout: 1000 })) {
          await acceptBtn.first().click();
          console.log('✓ Cookies GDPR acceptés');
          await page.waitForTimeout(300); // Réduire le timeout
          break;
        }
      }
      
      // Si pas trouvé au premier attempt, attendre un peu plus
      if (attempt < 2) await page.waitForTimeout(1000);
      
    } catch (e) {
      console.log(`⚠️ Tentative ${attempt + 1}/3 popup GDPR - ${e.message}`);
      if (attempt === 2) console.log('⚠️ Popup GDPR non géré après 3 tentatives');
    }
  }
  
  // 2. Popup de connexion/modal générique avec gestion d'erreur
  try {
    const loginModal = page.locator('.modal-popup, .authentication-popup, [data-role="modal"]')
      .filter({ hasNotText: /cookies|gdpr/i }); // Exclure modals GDPR
    
    if (await loginModal.isVisible({ timeout: 1000 })) {
      // Essayer fermeture avec plusieurs stratégies
      const closeBtn = loginModal.locator('.action-close, .modal-close, [aria-label*="Close"], [aria-label*="Fermer"]')
        .or(page.locator('button').filter({ hasText: /×|close|fermer/i }));
      
      if (await closeBtn.first().isVisible({ timeout: 500 })) {
        await closeBtn.first().click();
        console.log('✓ Popup modal fermé');
      } else {
        // Fallback: ESC key
        await page.keyboard.press('Escape');
        console.log('✓ Popup fermé avec ESC');
      }
      await page.waitForTimeout(300);
    }
  } catch (e) {
    console.log(`ℹ️ Aucun popup modal détecté ou déjà fermé`);
  }
  
  // 3. Attendre stabilisation finale avec timeout réduit
  await page.waitForLoadState('networkidle', { timeout: 5000 });
}

/**
 * Se connecte au site FLB
 */
async function loginToFLB(page, email, password, dadhriNumber = '') {
  // Navigation intelligente vers la page de connexion
  await smartNavigate(page, 'https://www.flbsolutions.com/customer/account/login/', {
    waitForSelectors: ['input[name="login[email]"]'],
    timeout: 15000
  });
  
  // Gérer les popups potentiels avant de remplir le formulaire
  await handleFLBPopups(page);
  
  // Remplissage intelligent du formulaire
  // Email avec sélecteurs multiples et vérification
  const emailSelector = 'form[data-role="email-with-possible-login"] input[name="login[email]"], input[name="login[email]"], #email';
  await smartFill(page, emailSelector, email, { verifyValue: true });
  
  // Champ numéro Dadhri (optionnel) 
  try {
    const dadhriField = await waitForElementReady(page, 'input[name="dadhri-number"], #dadhri-number', {
      timeout: 2000,
      retries: 1
    });
    if (dadhriNumber) {
      await smartFill(page, 'input[name="dadhri-number"], #dadhri-number', dadhriNumber);
      console.log('✓ Numéro Dadhri renseigné');
    }
  } catch (e) {
    console.log('ℹ️ Champ Dadhri non trouvé ou non requis');
  }
  
  // Mot de passe avec sélecteurs robustes
  const passwordSelector = 'form[data-role="email-with-possible-login"] input[name="login[password]"], input[name="login[password]"], input[type="password"][name="password"]';
  await smartFill(page, passwordSelector, password, { verifyValue: true });
  
  // Soumission intelligente avec attente de réponse
  const submitSelector = 'form[data-role="email-with-possible-login"] button[type="submit"], #send2, button[type="submit"]';
  await smartClick(page, submitSelector, { 
    waitForResponse: true,
    responseTimeout: 8000 
  });
  
  // Gérer le popup de sélection livraison/ramassage
  await handleDeliveryPopup(page);
  
  // Vérification connexion réussie
  await page.waitForURL(/customer\/account/, { timeout: 10000 });
  console.log('✓ Connexion réussie avec smart helpers');
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