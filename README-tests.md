# 🧪 Tests de Régression FLB Solutions

Tests automatisés E2E avec Playwright pour le site FLB Solutions.
**Environnement virtuel intégré - Aucune installation globale requise !**

## 🚀 Utilisation Ultra-Simple

### Première utilisation
```bash
# Le script configure tout automatiquement
./run-tests.sh setup
```

### Lancer les tests
```bash
# Tests smoke (défaut, 2-3 min)
./run-tests.sh

# Tests authentifiés
./run-tests.sh auth

# Tests multi-navigateurs  
./run-tests.sh multi

# Mode debug avec interface
./run-tests.sh debug
```

## 📋 Commandes Disponibles

| Commande | Description | Durée |
|----------|-------------|-------|
| `./run-tests.sh setup` | Configuration interactive des credentials | 30s |
| `./run-tests.sh` | Tests smoke (défaut) | 2-3 min |
| `./run-tests.sh auth` | Tests authentifiés | 3-5 min |
| `./run-tests.sh all` | Tous les tests | 5-10 min |
| `./run-tests.sh multi` | Multi-navigateurs (Chrome/Firefox/Safari) | 10-15 min |
| `./run-tests.sh parallel` | Tests en parallèle | 5-8 min |
| `./run-tests.sh debug` | Mode debug avec interface | Variable |
| `./run-tests.sh report` | Voir le rapport HTML | Instantané |
| `./run-tests.sh clean` | Nettoyer l'environnement | 30s |
| `./run-tests.sh help` | Aide complète | Instantané |

## 🔧 Fonctionnalités Automatiques

### ✅ Gestion d'Environnement
- **Environnement virtuel Node.js** : Installation automatique des dépendances
- **Navigateurs Playwright** : Installation automatique (Chrome, Firefox, Safari)
- **Variables d'environnement** : Chargement automatique depuis `.env`

### ✅ Configuration Interactive
Le script `setup` vous demande :
- 📧 **Email de connexion** : `cboulet@flbsolutions.com` (pré-rempli)
- 🏷️ **Numéro Dadhri** : `BOULETC` (pré-rempli)  
- 🔒 **Mot de passe** : Saisie masquée et sécurisée

### ✅ Gestion des Popups
Gestion automatique de :
- 🍪 **Popup GDPR/Cookies** : Acceptation automatique
- 🔐 **Popup de connexion** : Fermeture automatique  
- 📦 **Popup Livraison/Ramassage** : Sélection date dans 2 jours

## 📊 Structure des Tests

### 🚨 Tests Smoke (2-3 min)
Tests de disponibilité critiques :
- ✅ Accueil accessible
- ✅ Catalogue accessible  
- ✅ Connexion fonctionnelle
- ✅ Recherche disponible
- ✅ Panier accessible

### 🔐 Tests Authentifiés (3-5 min)
Tests nécessitant une connexion :
- ✅ Prix visibles après login
- ✅ Ajout au panier fonctionne
- ✅ Accès Mon Compte

### 🏗️ Tests Critiques (5-10 min)
Tests des fonctionnalités business :
- 🛒 Processus de commande complet
- 💳 Processus de paiement
- 📦 Gestion livraison/ramassage
- 🔍 Recherche avancée

## 🛠️ Gestion des Popups

Le système gère automatiquement :

### 1. 🍪 Popup GDPR/Cookies
- Acceptation automatique des cookies
- Fermeture avec bouton "Accepter"

### 2. 🔐 Popup de Connexion
- Fermeture automatique avec bouton X
- Ou touche ESC en fallback

### 3. 📦 Popup Livraison/Ramassage
- Sélection automatique date dans 2 jours
- Choix du premier créneau disponible
- Confirmation automatique

## 📁 Configuration des Fichiers

### `.env` (créé par `setup`)
```env
FLB_TEST_EMAIL=votre.email@flbsolutions.com
FLB_TEST_PASSWORD=votre_mot_de_passe
FLB_TEST_DADHRI=VOTRE_DADHRI
```

### `playwright.config.js`
Configuration multi-navigateurs, timeouts, et options de test.

## 🐛 Résolution de Problèmes

### Tests qui échouent
1. **Vérifier les identifiants** : `npm run setup`
2. **Vérifier la connexion** : site accessible manuellement ?
3. **Réinstaller navigateurs** : `npx playwright install`

### Popups qui bloquent
Les scripts gèrent automatiquement les popups courants. Si nouveaux popups :
1. Examiner les logs de test
2. Mettre à jour `flb-helpers.js`

### Sélecteurs obsolètes
Si l'interface change :
1. Examiner le rapport d'erreur
2. Mettre à jour les sélecteurs dans les fichiers `.spec.js`

## 📈 Intégration CI/CD

Pour Jenkins/GitHub Actions :
```bash
# Variables d'environnement requises
FLB_TEST_EMAIL=email@flbsolutions.com
FLB_TEST_PASSWORD=password
FLB_TEST_DADHRI=DADHRI_CODE

# Commande CI
npm ci && npx playwright install && npm run test
```

## 📞 Support

En cas de problème :
1. Vérifier la console de sortie des tests
2. Utiliser `npm run test:headed` pour voir visuellement
3. Consulter le rapport HTML avec `npm run report`

---
*Dernière mise à jour : $(date)*