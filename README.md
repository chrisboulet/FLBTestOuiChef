# FLB Solutions - Tests de Régression Automatisés

![Tests Status](https://github.com/chrisboulet/FLBTestOuiChef/actions/workflows/docker-ci.yml/badge.svg)
![Playwright Version](https://img.shields.io/badge/Playwright-1.54.1-green)
![Node Version](https://img.shields.io/badge/Node-18+-green)

## 🎯 Vue d'Ensemble

Suite de tests de régression automatisés pour **FLB Solutions** utilisant Playwright. Conçue pour garantir la stabilité et la qualité du site e-commerce Magento dans un environnement de production critique.

### **Objectifs**
- ✅ **Stabilité** : Success rate 95%+ (actuellement 19% → 95%+)
- ✅ **Performance** : Tests <2min, détection rapide des régressions
- ✅ **Robustesse** : Sélecteurs intelligents, gestion popup avancée
- ✅ **Maintenabilité** : Architecture modulaire, helpers réutilisables

## 📊 Métriques Actuelles

| Métrique | Avant | Cible | Status |
|----------|-------|--------|--------|
| Success Rate | 19% (7/36) | 95%+ | 🔄 En cours |
| Strict Mode Violations | 18 tests | 0 | ✅ Résolu |
| Timeout Issues | 6 tests | 0 | ✅ Résolu |
| Generic Selectors | 8 tests | 0 | ✅ Résolu |
| Configuration Issues | Multiple | Unifié | ✅ Résolu |

## 🚀 Installation & Configuration

### **Prérequis**
- Node.js 18+
- npm ou yarn
- Accès FLB Solutions (VPN si nécessaire)

### **Installation**
```bash
# Cloner le repository
git clone https://github.com/chrisboulet/FLBTestOuiChef.git
cd FLBTestOuiChef

# Installer les dépendances
npm install

# Installer les navigateurs Playwright
npx playwright install

# Configurer les credentials (optionnel pour tests authentifiés)
npm run setup
```

### **Configuration Environnement**
```bash
# Copier et configurer les variables d'environnement
cp .env.example .env

# Modifier .env avec vos credentials de test
FLB_TEST_EMAIL=votre-email@flbsolutions.com
FLB_TEST_PASSWORD=votre-mot-de-passe
FLB_TEST_DADHRI=VOTRE_CODE_DADHRI
```

## 🧪 Utilisation

### **Scripts Disponibles**

```bash
# Tests de base (smoke tests)
npm run test:smoke

# Tests authentifiés (require credentials)
npm run test:auth

# Tests avec interface graphique
npm run test:headed

# Tests multi-navigateurs
npm run test:all-browsers

# Tests en parallèle (4 workers)
npm run test:parallel

# Génération du rapport
npm run report
```

### **Docker (Recommandé pour CI/CD)**

```bash
# Build et run avec Docker Compose
docker-compose up --build

# Tests en mode CI
docker-compose -f docker-compose.yml run --rm playwright npm test

# Monitoring avec Grafana
docker-compose up -d grafana prometheus
# Accès: http://localhost:3000 (admin/admin)
```

## 🏗️ Architecture

### **Structure du Projet**
```
├── tests/
│   ├── smoke/                    # Tests de base (non-authentifiés)
│   │   ├── flb-smoke.spec.js     # Navigation, recherche, panier
│   │   └── flb-authenticated.spec.js # Tests utilisateur connecté
│   ├── helpers/                  # Utilitaires réutilisables
│   │   ├── flb-helpers.js        # Helpers spécifiques FLB
│   │   ├── smart-waits.js        # Attentes intelligentes
│   │   └── popup-handler.js      # Gestion popups GDPR
│   └── flb-basic.spec.js         # Tests de base
├── docker/                       # Infrastructure containerisée
│   ├── grafana/                  # Monitoring & dashboards
│   ├── nginx/                    # Reverse proxy
│   └── scripts/                  # Scripts de déploiement
├── .github/workflows/            # CI/CD GitHub Actions
└── playwright.config.js         # Configuration Playwright
```

### **Composants Clés**

#### **1. Smart Helpers (`tests/helpers/smart-waits.js`)**
- `smartNavigate()` : Navigation avec retry pattern
- `smartFill()` : Remplissage de champs avec vérification
- `smartClick()` : Clicks intelligents avec attente de réponse
- `waitForElementReady()` : Attentes robustes avec retry

#### **2. FLB Helpers (`tests/helpers/flb-helpers.js`)**
- `loginToFLB()` : Authentification 3-champs (email, password, dadhri)
- `handleFLBPopups()` : Gestion popup GDPR avec retry pattern
- `handleDeliveryPopup()` : Popup livraison/ramassage post-connexion

#### **3. Configuration Unifiée (`playwright.config.js`)**
- Timeouts cohérents : action (10s), navigation (30s)
- Multi-navigateurs : Chrome, Firefox, Safari, Mobile
- Retry automatique en CI (2x)
- Screenshots et vidéos sur échec

## 🔧 Personnalisation

### **Ajout de Nouveaux Tests**

```javascript
// tests/custom/mon-test.spec.js
const { test, expect } = require('@playwright/test');
const { smartNavigate, smartClick } = require('../helpers/smart-waits');
const { handleFLBPopups } = require('../helpers/flb-helpers');

test.describe('Mon Nouveau Test', () => {
  test('Ma fonctionnalité', async ({ page }) => {
    await smartNavigate(page, '/ma-page', {
      waitForSelectors: ['.mon-element'],
      timeout: 15000
    });
    
    await handleFLBPopups(page);
    
    await smartClick(page, '.mon-bouton', {
      waitForResponse: true
    });
    
    await expect(page.locator('.resultat')).toBeVisible();
  });
});
```

### **Configuration Custom**

```javascript
// playwright.config.js - Ajout d'un nouveau project
{
  name: 'custom-env',
  use: { 
    baseURL: 'https://staging.flbsolutions.com',
    ...devices['Desktop Chrome']
  },
}
```

## 🚦 CI/CD & GitHub Workflow

### **GitHub Actions** (`.github/workflows/docker-ci.yml`)

**Déclencheurs :**
- Push sur `main`, `develop`
- Pull Requests
- Schedule quotidien (6h UTC)

**Pipeline :**
1. **Setup** : Node.js, cache npm
2. **Install** : Dependencies, Playwright browsers
3. **Test** : Smoke tests + authentifiés
4. **Docker** : Build & push images
5. **Deploy** : Staging auto, production manuel
6. **Notify** : Slack/Teams sur échec

### **Workflow Recommandé**

#### **1. Développement**
```bash
git checkout -b feature/mon-amelioration
# Développement et tests locaux
npm run test:smoke
npm run test:auth
git commit -m "feat: amélioration X"
git push origin feature/mon-amelioration
```

#### **2. Pull Request**
- **Automatique** : Tests CI, Docker build
- **Manuel** : Code review, validation QA
- **Merge** : Squash & merge vers `main`

#### **3. Release**
```bash
# Tagging sémantique
git tag v1.2.0
git push origin v1.2.0

# Publication automatique Docker Hub
# Déploiement staging automatique
# Déploiement production manuel via GitHub Environments
```

## 📋 GitHub Issues & Templates

### **Types d'Issues**

#### **🐛 Bug Report**
```markdown
**Environnement**
- Navigateur : Chrome/Firefox/Safari
- Version : 
- OS : Windows/macOS/Linux

**Description**
Test qui échoue de manière reproductible

**Étapes de Reproduction**
1. Lancer `npm run test:smoke`
2. Observer l'échec sur...

**Comportement Attendu**
Test doit passer

**Logs**
```bash
[logs ici]
```

**Labels :** `bug`, `priority:high/medium/low`, `browser:chrome`
```

#### **✨ Feature Request**
```markdown
**User Story**
En tant que [rôle], je veux [fonctionnalité] pour [bénéfice]

**Critères d'Acceptation**
- [ ] Critère 1
- [ ] Critère 2
- [ ] Tests ajoutés

**Définition of Done**
- [ ] Tests passent (95%+ success rate)
- [ ] Documentation mise à jour
- [ ] Code review approuvé

**Labels :** `enhancement`, `priority:medium`, `help wanted`
```

#### **🔧 Maintenance**
```markdown
**Type de Maintenance**
- [ ] Mise à jour dépendances
- [ ] Refactoring
- [ ] Performance
- [ ] Sécurité

**Impact**
Description de l'impact sur les tests existants

**Plan de Migration**
Étapes pour migrer sans casser les tests

**Labels :** `maintenance`, `dependencies`, `refactoring`
```

### **Labels Standards**

**Type :**
- `bug` : Dysfonctionnement
- `enhancement` : Nouvelle fonctionnalité
- `maintenance` : Maintenance technique
- `documentation` : Documentation

**Priorité :**
- `priority:critical` : Bloque la production
- `priority:high` : Impact important
- `priority:medium` : Amélioration notable
- `priority:low` : Nice to have

**Navigateur :**
- `browser:chrome`, `browser:firefox`, `browser:safari`
- `mobile` : Tests mobiles

**Status :**
- `needs-triage` : Nouveau, à évaluer
- `in-progress` : En cours
- `needs-review` : Prêt pour review
- `blocked` : Bloqué par dépendance

## 🔐 Sécurité & Credentials

### **Gestion des Secrets**

**Localement :**
```bash
# .env (gitignored)
FLB_TEST_EMAIL=test@example.com
FLB_TEST_PASSWORD="mot-de-passe-sécurisé"
FLB_TEST_DADHRI=CODE123
```

**GitHub Secrets :**
- `FLB_TEST_EMAIL` : Email de test
- `FLB_TEST_PASSWORD` : Mot de passe (chiffré)
- `FLB_TEST_DADHRI` : Code Dadhri
- `DOCKER_HUB_TOKEN` : Publication images

**Bonnes Pratiques :**
- ❌ Jamais de credentials dans le code
- ✅ Rotation régulière des mots de passe de test
- ✅ Comptes de test dédiés (non-production)
- ✅ Audit des accès régulier

## 🔍 Debugging & Troubleshooting

### **Tests qui Échouent**

```bash
# Mode debug avec interface
npm run test:headed

# Tests spécifiques
npx playwright test tests/smoke/flb-smoke.spec.js --headed

# Avec inspect mode
npx playwright test --debug

# Voir les traces
npx playwright show-trace trace.zip
```

### **Problèmes Courants**

#### **1. Timeouts**
```javascript
// ❌ Timeout fixe
await page.waitForTimeout(5000);

// ✅ Smart wait
await waitForElementReady(page, '.mon-element', {
  timeout: 10000,
  retries: 3
});
```

#### **2. Sélecteurs Fragiles**
```javascript
// ❌ Sélecteur générique
page.locator('text=Catalogue')

// ✅ Sélecteur robuste
page.locator('nav a').filter({ hasText: /^Catalogue$/i })
  .or(page.locator('a[href*="tous-les-produits"]'))
```

#### **3. Popups Non Gérés**
```javascript
// ✅ Toujours gérer les popups
await handleFLBPopups(page);
```

### **Monitoring**

```bash
# Accès Grafana monitoring
docker-compose up -d grafana
# http://localhost:3000 (admin/admin)

# Métriques disponibles :
# - Success rate par test
# - Temps d'exécution
# - Taux d'échec par navigateur
# - Performance trends
```

## 📈 Métriques & Reporting

### **KPIs Surveillés**

| Métrique | Objectif | Alerte Si |
|----------|----------|-----------|
| Success Rate Global | >95% | <90% |
| Temps Exécution Moy | <2min | >3min |
| Tests Flaky | <5% | >10% |
| Coverage Fonctionnel | >80% | <70% |

### **Rapports Automatiques**

- **Daily** : Rapport success rate (Slack)
- **Weekly** : Tendances performance (Email)
- **Release** : Rapport complet (GitHub)
- **Incident** : Alerte immédiate (Teams)

## 🤝 Contribution

### **Development Workflow**

1. **Fork** le repository
2. **Clone** votre fork
3. **Branch** depuis `main` : `git checkout -b feature/ma-feature`
4. **Develop** avec tests locaux : `npm run test:smoke`
5. **Commit** avec messages conventionnels : `feat: add new test`
6. **Push** et créer **Pull Request**
7. **Review** par l'équipe
8. **Merge** après approbation

### **Standards Code**

- **ESLint** : `npm run lint`
- **Prettier** : `npm run format`
- **Tests** : Coverage >80%
- **Commits** : [Conventional Commits](https://conventionalcommits.org/)

### **Pull Request Template**

```markdown
## Description
Brève description des changements

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle fonctionnalité  
- [ ] Breaking change
- [ ] Documentation

## Tests
- [ ] Tests locaux passent
- [ ] Tests CI passent
- [ ] Nouveaux tests ajoutés si nécessaire

## Checklist
- [ ] Code reviewé par moi-même
- [ ] Code suit les standards du projet
- [ ] Commentaires ajoutés pour code complexe
- [ ] Documentation mise à jour
```

## 🆘 Support

### **Contacts**

- **Tech Lead** : [@chrisboulet](https://github.com/chrisboulet)
- **QA Team** : qa-team@flbsolutions.com
- **Issues** : [GitHub Issues](https://github.com/chrisboulet/FLBTestOuiChef/issues)

### **Resources**

- [Playwright Documentation](https://playwright.dev)
- [FLB Solutions API](https://api.flbsolutions.com/docs)
- [Internal Wiki](https://wiki.flbsolutions.com/tests)

---

## 📄 License

MIT License - Voir [LICENSE](LICENSE) pour détails.

---

**Dernière mise à jour :** Juillet 2025  
**Version :** v1.0.0  
**Mainteneur :** [@chrisboulet](https://github.com/chrisboulet)