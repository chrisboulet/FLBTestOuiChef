# 🐳 FLB Solutions - Dockerfile Optimisé

**Version 2.0.0** - Container Playwright E2E prêt pour production

## 🎯 Objectifs Atteints

### ✅ **Phase 1 - Environnement Playwright Stable**
- **Node.js 18 LTS** avec optimisation mémoire (4GB max)
- **Navigateurs complets** : Chromium, Firefox, WebKit avec dépendances
- **Multi-stage build** optimisé pour performance et sécurité
- **Base Alpine** pour image minimale + Ubuntu pour navigateurs
- **Utilisateur non-root** `flbtest` avec permissions sécurisées

### ✅ **Performance & Optimisation**
- **Build rapide** : Layer caching intelligent, copie optimisée
- **Taille réduite** : Multi-stage avec nettoyage automatique
- **Démarrage <30s** : Pré-chargement des modules critiques
- **WSL2 compatible** : Tests validés Linux/WSL2

### ✅ **Sécurité Production**
- **Scan Trivy** intégré dans le build
- **Secrets management** avec volumes sécurisés
- **Health checks** robustes avec retry
- **Monitoring** intégré (Prometheus + Grafana)

## 🏗️ Architecture Multi-Stage

```
┌─── Stage 1: base ──────────────┐
│ Node.js 18 + Alpine + Security │
├─── Stage 2: dependencies ──────┤  
│ NPM install + Playwright CLI   │
├─── Stage 3: browsers ──────────┤
│ Ubuntu + Navigateurs complets  │
├─── Stage 4: runtime ───────────┤
│ Environnement test + GUI       │
└─── Stage 5: production ────────┘
  Code + Scripts + Health + OCI
```

## 🚀 Utilisation Rapide

### **Build Standard**
```bash
# Construction optimisée
./docker/scripts/build.sh

# Build avec scan sécurité
./docker/scripts/build.sh --scan

# Build développement
./docker/scripts/build.sh --dev
```

### **Docker Compose (Recommandé)**
```bash
# Démarrage complet avec monitoring
docker-compose -f docker-compose.flb-optimized.yml up

# Tests uniquement
docker-compose -f docker-compose.flb-optimized.yml up flb-tests

# Mode développement
ENV_TYPE=dev HEADLESS=false docker-compose -f docker-compose.flb-optimized.yml up
```

### **Docker Run Direct**
```bash
# Tests standard
docker run --rm -v $(pwd)/test-results:/app/test-results \
  flb-solutions/playwright-tests:2.0.0

# Tests avec interface graphique
docker run --rm -e HEADLESS=false -e ENV_TYPE=dev \
  -v $(pwd)/test-results:/app/test-results \
  flb-solutions/playwright-tests:2.0.0

# Shell interactif
docker run --rm -it flb-solutions/playwright-tests:2.0.0 bash
```

## ⚙️ Configuration Environnements

### **Variables d'Environnement**
```bash
# Environnement
ENV_TYPE=test|dev|staging|prod     # Mode d'exécution
NODE_ENV=test|development|production
DEBUG=false|true                   # Logs détaillés

# Tests Playwright  
HEADLESS=true|false                # Mode graphique
PARALLEL_WORKERS=4                 # Parallélisme
RETRY_FAILED=2                     # Retry sur échec
SCREENSHOT_MODE=only-on-failure    # Captures d'écran

# URLs et configuration
BASE_URL=https://www.flbsolutions.com
KEEP_ALIVE=false                   # Maintenir container
```

### **Profils d'Environnement**
```yaml
# Développement
ENV_TYPE: dev
HEADLESS: false
PARALLEL_WORKERS: 2
SCREENSHOT_MODE: on

# Test/CI
ENV_TYPE: test  
HEADLESS: true
PARALLEL_WORKERS: 4
SCREENSHOT_MODE: only-on-failure

# Production
ENV_TYPE: prod
HEADLESS: true
PARALLEL_WORKERS: 8
RETRY_FAILED: 3
```

## 📁 Structure Volumes

```
project/
├── test-results/     # Résultats des tests
├── reports/         # Rapports HTML Playwright  
├── screenshots/     # Captures d'écran
├── videos/         # Enregistrements vidéo
└── config/         # Configuration et secrets
```

## 🔍 Monitoring & Health

### **Endpoints Disponibles**
- **Health Check** : `http://localhost:3000/health`
- **Rapport Playwright** : `http://localhost:9323`
- **Prometheus** : `http://localhost:9090`
- **Grafana** : `http://localhost:3001` (admin:flb2025!)

### **Health Check Avancé**
```bash
# Check manuel
docker exec flb-tests-main /app/scripts/health-check.sh

# Logs de santé
docker logs flb-tests-main | grep HEALTH
```

## 🛠️ Scripts d'Orchestration

### **Build Script**
```bash
./docker/scripts/build.sh [OPTIONS]

Options:
  -t, --target TARGET    # Target de build (production)
  -n, --no-cache        # Build sans cache
  -s, --scan            # Scan sécurité Trivy
  -d, --dev             # Mode développement
  -p, --push            # Push vers registry
  -c, --clean           # Nettoyage avant build
```

### **Entrypoint Intelligent**
- **Auto-configuration** par environnement
- **Gestion des signaux** SIGTERM/SIGINT
- **Validation** avant exécution
- **Sauvegarde** automatique des résultats
- **Health server** pour monitoring

## 🔒 Sécurité

### **Bonnes Pratiques Implémentées**
- ✅ **Utilisateur non-root** (flbtest:1001)
- ✅ **Image minimale** Alpine + nettoyage
- ✅ **Secrets externes** via volumes
- ✅ **Scan vulnérabilités** Trivy intégré
- ✅ **Permissions restreintes** 
- ✅ **Health checks** robustes

### **Scan Sécurité**
```bash
# Build avec scan automatique
./docker/scripts/build.sh --scan

# Scan manuel
trivy image flb-solutions/playwright-tests:2.0.0
```

## 📊 Performance

### **Métriques Cibles**
- **Build time** : <5 min (avec cache)
- **Image size** : <2GB (multi-stage optimisé)
- **Start time** : <30s (pré-chargement)
- **Memory usage** : <4GB (limite configurée)

### **Optimisations Appliquées**
- ✅ **Multi-stage build** avec copie intelligente
- ✅ **Layer caching** optimisé
- ✅ **Dependencies** figées et nettoyées
- ✅ **Fonts** minimalistes
- ✅ **Modules pré-chargés**

## 🔧 Dépannage

### **Problèmes Courants**
```bash
# Navigateurs manquants
docker run --rm -it flb-solutions/playwright-tests:2.0.0 \
  npx playwright install

# Permissions répertoires
docker exec flb-tests-main chown -R flbtest:flbtest /app/test-results

# Mémoire insuffisante
# Augmenter limite Docker ou réduire PARALLEL_WORKERS
```

### **Logs Utiles**
```bash
# Logs conteneur principal
docker logs flb-tests-main -f

# Logs par service (compose)
docker-compose -f docker-compose.flb-optimized.yml logs flb-tests

# Debug health check
docker exec flb-tests-main /app/scripts/health-check.sh
```

## 🎯 Prochaines Étapes

### **Phase 2 - Évolutions**
- [ ] **Registry privé** avec authentification
- [ ] **Pipeline CI/CD** GitHub Actions/GitLab
- [ ] **Scaling horizontal** Kubernetes
- [ ] **Cache distributé** Redis cluster
- [ ] **Métriques avancées** OpenTelemetry

### **Intégration Continue**
```yaml
# .github/workflows/docker.yml
- name: Build and test
  run: |
    ./docker/scripts/build.sh --scan
    docker-compose -f docker-compose.flb-optimized.yml up --abort-on-container-exit
```

## 📞 Support

**FLB Solutions DevOps Team**
- 📧 Email : devops@flbsolutions.com
- 📚 Documentation : https://docs.flbsolutions.com/testing
- 🐛 Issues : Repository GitHub/GitLab

---

> **🎉 Félicitations !** Votre environnement Playwright FLB est maintenant prêt pour la production avec toutes les optimisations de performance et sécurité.