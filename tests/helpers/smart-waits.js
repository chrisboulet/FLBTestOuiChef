// Smart waits et helpers d'attente intelligente pour éviter les timeouts arbitraires

/**
 * Attendre qu'un élément soit prêt pour interaction avec retry pattern
 */
async function waitForElementReady(page, selector, options = {}) {
  const {
    timeout = 10000,
    retries = 3,
    stabilityTime = 100,
    action = 'visible'
  } = options;

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const element = page.locator(selector);
      
      switch (action) {
        case 'visible':
          await element.waitFor({ state: 'visible', timeout: timeout / retries });
          break;
        case 'attached':
          await element.waitFor({ state: 'attached', timeout: timeout / retries });
          break;
        case 'clickable':
          await element.waitFor({ state: 'visible', timeout: timeout / retries });
          await element.waitFor({ state: 'attached', timeout: 1000 });
          break;
      }
      
      // Attendre stabilité (éviter éléments qui bougent)
      await page.waitForTimeout(stabilityTime);
      
      // Vérifier que l'élément est toujours disponible
      if (await element.isVisible()) {
        return element;
      }
      
    } catch (e) {
      console.log(`⚠️ Tentative ${attempt + 1}/${retries} pour ${selector} - ${e.message}`);
      if (attempt < retries - 1) {
        await page.waitForTimeout(1000); // Backoff progressif
      }
    }
  }
  
  throw new Error(`Élément ${selector} non trouvé après ${retries} tentatives`);
}

/**
 * Attendre que la page soit stable (plus de changements DOM)
 */
async function waitForPageStability(page, options = {}) {
  const {
    timeout = 10000,
    stabilityTime = 500,
    maxChecks = 20
  } = options;

  let stableCount = 0;
  let lastBodyContent = '';
  
  for (let i = 0; i < maxChecks; i++) {
    try {
      // Attendre un peu
      await page.waitForTimeout(stabilityTime / 4);
      
      // Vérifier stabilité DOM
      const currentContent = await page.locator('body').innerHTML();
      
      if (currentContent === lastBodyContent) {
        stableCount++;
        if (stableCount >= 2) { // 2 vérifications identiques = stable
          console.log('✓ Page stable détectée');
          return;
        }
      } else {
        stableCount = 0;
        lastBodyContent = currentContent;
      }
      
    } catch (e) {
      console.log(`⚠️ Vérification stabilité ${i + 1}/${maxChecks} - ${e.message}`);
    }
  }
  
  console.log('⚠️ Timeout stabilité - continue avec page potentiellement instable');
}

/**
 * Smart navigation avec attente de chargement complet
 */
async function smartNavigate(page, url, options = {}) {
  const {
    waitForSelectors = [],
    timeout = 30000,
    retries = 2
  } = options;

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      console.log(`🔗 Navigation vers ${url} (tentative ${attempt + 1}/${retries})`);
      
      // Navigation avec attente réseau
      await page.goto(url, { 
        waitUntil: 'domcontentloaded',
        timeout: timeout / retries 
      });
      
      // Attendre stabilisation réseau
      await page.waitForLoadState('networkidle', { timeout: 5000 });
      
      // Attendre sélecteurs spécifiques si fournis
      for (const selector of waitForSelectors) {
        await waitForElementReady(page, selector, { timeout: 3000, retries: 1 });
      }
      
      console.log('✓ Navigation réussie');
      return;
      
    } catch (e) {
      console.log(`⚠️ Échec navigation tentative ${attempt + 1} - ${e.message}`);
      if (attempt < retries - 1) {
        await page.waitForTimeout(2000); // Backoff entre tentatives
      }
    }
  }
  
  throw new Error(`Navigation vers ${url} échouée après ${retries} tentatives`);
}

/**
 * Smart fill - remplissage de champ avec vérification
 */
async function smartFill(page, selector, value, options = {}) {
  const {
    clearFirst = true,
    verifyValue = true,
    retries = 3
  } = options;

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const element = await waitForElementReady(page, selector, { 
        action: 'clickable',
        timeout: 5000 
      });
      
      // Effacer le champ si demandé
      if (clearFirst) {
        await element.clear();
        await page.waitForTimeout(100);
      }
      
      // Remplir
      await element.fill(value);
      
      // Vérifier la valeur si demandé
      if (verifyValue) {
        await page.waitForTimeout(200);
        const actualValue = await element.inputValue();
        if (actualValue === value) {
          console.log(`✓ Champ ${selector} rempli avec "${value}"`);
          return;
        } else {
          throw new Error(`Valeur attendue "${value}", obtenue "${actualValue}"`);
        }
      }
      
      return;
      
    } catch (e) {
      console.log(`⚠️ Tentative ${attempt + 1}/${retries} fill ${selector} - ${e.message}`);
      if (attempt < retries - 1) {
        await page.waitForTimeout(500);
      }
    }
  }
  
  throw new Error(`Impossible de remplir ${selector} après ${retries} tentatives`);
}

/**
 * Smart click avec vérification d'état
 */
async function smartClick(page, selector, options = {}) {
  const {
    timeout = 10000,
    retries = 3,
    waitForResponse = false,
    responseTimeout = 5000
  } = options;

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const element = await waitForElementReady(page, selector, { 
        action: 'clickable',
        timeout: timeout / retries 
      });
      
      // Attendre les réponses si demandé
      let responsePromise;
      if (waitForResponse) {
        responsePromise = page.waitForResponse(response => 
          response.status() === 200 && response.request().method() === 'POST',
          { timeout: responseTimeout }
        );
      }
      
      // Cliquer
      await element.click();
      console.log(`✓ Click réussi sur ${selector}`);
      
      // Attendre la réponse si configuré
      if (waitForResponse && responsePromise) {
        await responsePromise;
        console.log('✓ Réponse serveur reçue');
      }
      
      return;
      
    } catch (e) {
      console.log(`⚠️ Tentative ${attempt + 1}/${retries} click ${selector} - ${e.message}`);
      if (attempt < retries - 1) {
        await page.waitForTimeout(1000);
      }
    }
  }
  
  throw new Error(`Impossible de cliquer ${selector} après ${retries} tentatives`);
}

module.exports = {
  waitForElementReady,
  waitForPageStability,
  smartNavigate,
  smartFill,
  smartClick
};