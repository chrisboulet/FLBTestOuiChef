# Pull Request

## 📋 Description

**Résumé des changements**
Brève description des modifications apportées.

**Issue liée**
Fixes #(numéro de l'issue)

**Motivation et contexte**
Pourquoi ce changement est-il nécessaire ? Quel problème résout-il ?

## 🔄 Type de changement

Sélectionner le type de changement :

- [ ] 🐛 **Bug fix** (changement qui corrige un problème)
- [ ] ✨ **New feature** (changement qui ajoute une fonctionnalité)
- [ ] 💥 **Breaking change** (fix ou feature qui casserait la fonctionnalité existante)
- [ ] 📚 **Documentation** (mise à jour de la documentation uniquement)
- [ ] 🔧 **Maintenance** (refactoring, mise à jour dépendances, nettoyage)
- [ ] ⚡ **Performance** (amélioration des performances)
- [ ] 🧪 **Tests** (ajout ou modification de tests)

## 🧪 Tests

**Tests ajoutés/modifiés**
- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Tests smoke
- [ ] Tests authentifiés
- [ ] Tests multi-navigateurs

**Validation manuelle**
- [ ] Tests locaux passent (`npm run test:smoke`)
- [ ] Tests authentifiés passent (`npm run test:auth`)
- [ ] Tests multi-navigateurs OK (`npm run test:all-browsers`)
- [ ] Mode headed testé (`npm run test:headed`)

**Métriques de tests**
- Success rate avant : ____%
- Success rate après : ____%
- Temps d'exécution avant : ____min
- Temps d'exécution après : ____min

## 🔍 Code Review

**Self-review checklist**
- [ ] Code suit les standards du projet
- [ ] Pas de code mort ou commenté
- [ ] Variables et fonctions nommées clairement
- [ ] Commentaires ajoutés pour logique complexe
- [ ] Pas de secrets ou credentials hardcodés
- [ ] Gestion d'erreur appropriée

**Sélecteurs Playwright (si applicable)**
- [ ] Pas de sélecteurs fragiles (`text=`, génériques)
- [ ] Utilisation de sélecteurs robustes avec fallbacks
- [ ] Smart waits utilisés au lieu de timeouts fixes
- [ ] Gestion des popups implémentée

## 📊 Impact

**Fichiers modifiés**
- `tests/` : nombre de fichiers modifiés
- `helpers/` : nombre de fichiers modifiés  
- `config/` : configuration modifiée (oui/non)
- `docs/` : documentation mise à jour (oui/non)

**Rétrocompatibilité**
- [ ] Changement 100% rétrocompatible
- [ ] Breaking change mineur (avec migration guide)
- [ ] Breaking change majeur (version bump nécessaire)

**Navigateurs testés**
- [ ] Chrome/Chromium
- [ ] Firefox
- [ ] Safari/WebKit
- [ ] Mobile Chrome
- [ ] Tests cross-browser OK

## 🚀 Déploiement

**Prérequis de déploiement**
- [ ] Aucun prérequis
- [ ] Mise à jour environnement nécessaire
- [ ] Migration de données requise
- [ ] Mise à jour de configuration

**Stratégie de rollback**
- [ ] Rollback automatique possible (git revert)
- [ ] Rollback manuel avec procédure documentée
- [ ] Rollback complexe nécessitant intervention

## 📸 Screenshots/Logs

**Avant/Après** (si applicable)
<!-- Screenshots ou logs montrant l'amélioration -->

**Nouvelles fonctionnalités** (si applicable)
<!-- Captures d'écran des nouvelles fonctionnalités -->

## 📚 Documentation

**Mise à jour nécessaire**
- [ ] README.md
- [ ] Documentation technique
- [ ] Changelog
- [ ] Guide de migration
- [ ] Aucune mise à jour nécessaire

**Exemples d'usage** (si nouvelle feature)
```javascript
// Exemple d'utilisation de la nouvelle fonctionnalité
```

## ⚠️ Notes pour les Reviewers

**Points d'attention particuliers**
- Point spécifique à reviewer en priorité
- Logique complexe à ligne XXX
- Performance à vérifier

**Questions ouvertes**
- Question 1 : _____________
- Question 2 : _____________

---

## ✅ Checklist Finale

### Développeur
- [ ] Tests locaux passent à 100%
- [ ] Code self-reviewé
- [ ] Documentation mise à jour
- [ ] Commit message suit les conventions
- [ ] Branch à jour avec main
- [ ] Pas de conflicts

### CI/CD
- [ ] Tests automatiques passent
- [ ] Build Docker réussit
- [ ] Linting sans erreurs
- [ ] Security scan OK
- [ ] Performance tests OK

### Review
- [ ] Code review par au moins 1 personne
- [ ] Approbation QA (si applicable)
- [ ] Tests manuels validés
- [ ] Documentation reviewée

---

**Reviewers suggérés :** @chrisboulet
**Labels :** (à ajouter automatiquement selon le type)
**Milestone :** (si applicable)