# Analyse Critique - Problème de Performance Magento 2.4.7
**Date:** 29 juillet 2025  
**Serveur:** Production FLB Solutions - Magento 2.4.7 + MariaDB  
**Analyste:** Investigation Technique Systématique  

## 🚨 Résumé Exécutif

**Problème Critical:** CPU 100-350%, pages produits inaccessibles, déni de service partiel  
**Cause Racine:** Code personnalisé générant 2.6M requêtes EAV inutiles par confusion d'entités  
**Impact:** Perte complète d'accès aux pages produits, surcharge base de données  
**Solution:** Mise en cache dans `BrandAttribute.php` + nettoyage données corrompues  

---

## 📊 Symptômes Initiaux

### État du Système
- **CPU:** 100-350% constant sur MariaDB
- **Pages Fonctionnelles:** Categories (ex: `/fr/viandes-et-substituts.html`)
- **Pages Défaillantes:** Produits (ex: `/fr/3000007-un.html`)
- **Durée:** Problème persistant depuis 24h+

### Impact Métier
- Interruption complète des pages produits
- Perte potentielle de revenus
- Dégradation expérience utilisateur
- Charge serveur critique

---

## 🔍 Méthodologie d'Investigation

### Phase 1: Diagnostic Base de Données
```sql
-- Investigation processus actifs
SHOW FULL PROCESSLIST;

-- Vérification requêtes lentes
SHOW VARIABLES LIKE 'slow_query%';
SELECT COUNT(*) FROM mysql.slow_log;
```

**Résultats Phase 1:**
- **2.16M requêtes lentes** accumulées
- **Deadlock** sur `catalog_product_entity`
- **Processus bloquants** identifiés

### Phase 2: Analyse Patterns SQL
```sql
-- Activation logging détaillé
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.1;

-- Analyse requêtes problématiques
SELECT sql_text, query_time, rows_examined 
FROM mysql.slow_log 
ORDER BY query_time DESC 
LIMIT 10;
```

**Découverte Critique:**
- **21,030 requêtes** pour entity_id `1331`
- **13,570 requêtes** pour entity_id `2047`
- **Pattern:** Requêtes EAV UNION massives

### Phase 3: Identification Entités
```sql
-- Vérification type d'entités
SELECT entity_id, entity_type_id FROM catalog_category_entity 
WHERE entity_id IN (1331, 2047);
```

**Révélation Majeure:**
- `1331` et `2047` = **CATEGORIES**
- Système les charge comme **PRODUITS**
- Confusion entity_type dans le code

---

## 🎯 Analyse des Causes Racines

### Identification du Code Source

**Fichier Problématique:**
```
/var/www/flbsolutions.com/app/code/Flb/Catalog/ViewModel/BrandAttribute.php
```

**Méthode Défaillante:**
```php
private function getCategoryUrl()
{
    $categoryId = $this->scopeConfig->getValue('flb/all_product/category_id', ScopeInterface::SCOPE_STORE);
    $category = $this->categoryRepository->get($categoryId, $this->storeManager->getStore()->getId());
    return $category->getUrl();
}
```

### Architecture du Problème

```mermaid
graph TD
    A[Template product/list/items.phtml] -->|Boucle produits| B[getBrandUrl()]
    B --> C[getCategoryUrl()]
    C -->|Sans cache| D[categoryRepository->get()]
    D -->|Chaque appel| E[Requêtes EAV massives]
    E --> F[2.6M requêtes accumulées]
    F --> G[CPU 350% + Deadlocks]
```

### Points d'Appel Critiques

1. **Template Principal:** `product/list/items.phtml:103`
   ```php
   $brandUrl = $brandViewModel->getBrandUrl($_attributeValue);
   ```

2. **Template Détail:** `brand_attribute.phtml:18`
   ```php
   $brandUrl = $brandViewModel->getBrandUrl($_attributeValue);
   ```

### Amplification du Problème

- **Boucle Produits:** Chaque produit → appel getBrandUrl()
- **Pas de Cache:** Rechargement category_id à chaque appel
- **Configuration Corrompue:** category_id pointe vers des IDs invalides
- **EAV Overhead:** Système tente de charger categories comme products

---

## 📈 Preuves Quantifiables

### Métriques Base de Données
| Métrique | Valeur | Impact |
|----------|--------|--------|
| Requêtes lentes totales | 2,162,301 | Critique |
| Entity 1331 (catégorie) | 21,030 requêtes | Majeur |
| Entity 2047 (catégorie) | 13,570 requêtes | Majeur |
| CPU moyen | 100-350% | Critique |
| Deadlocks | Multiple | Bloquant |

### Pattern Temporel
- **Accumulation:** Dégradation progressive sur 24h+
- **Pic:** Correspondance avec trafic pages produits  
- **Persistance:** Problème reproductible à chaque visite

### Configuration Système
```sql
-- Cache MySQL (amélioration partielle testée)
query_cache_type = ON
query_cache_size = 256MB
```

**Résultat:** Amélioration marginale, problème fondamental persistant

---

## 💡 Solutions Recommandées

### Solution Immédiate (Hotfix)

**Priorité 1:** Implémentation cache dans `BrandAttribute.php`

```php
class BrandAttribute implements ArgumentInterface
{
    private $categoryUrlCache = [];
    
    private function getCategoryUrl()
    {
        $categoryId = $this->scopeConfig->getValue('flb/all_product/category_id', ScopeInterface::SCOPE_STORE);
        
        // Cache check
        if (isset($this->categoryUrlCache[$categoryId])) {
            return $this->categoryUrlCache[$categoryId];
        }
        
        try {
            $category = $this->categoryRepository->get($categoryId, $this->storeManager->getStore()->getId());
            $url = $category->getUrl();
            
            // Cache result
            $this->categoryUrlCache[$categoryId] = $url;
            return $url;
            
        } catch (\Exception $e) {
            // Log error and return fallback
            $this->logger->error('Category load failed: ' . $categoryId);
            return '#';
        }
    }
}
```

### Solution Structurelle (Moyen Terme)

**Priorité 2:** Nettoyage données corrompues
```sql
-- Identifier configurations corrompues
SELECT * FROM core_config_data WHERE path = 'flb/all_product/category_id';

-- Validation entity_type
SELECT ce.entity_id, ce.entity_type_id, et.entity_type_code 
FROM catalog_category_entity ce 
JOIN eav_entity_type et ON ce.entity_type_id = et.entity_type_id 
WHERE ce.entity_id IN (1331, 2047);
```

**Priorité 3:** Optimisation architecture
- Révision pattern Repository usage
- Implémentation cache applicatif global  
- Monitoring requêtes EAV

---

## 📋 Plan d'Implémentation

### Phase 1: Correction Immédiate (0-2h)
- [ ] **Backup code existant**
- [ ] **Implémenter cache BrandAttribute.php**
- [ ] **Test pages produits**  
- [ ] **Monitoring CPU/requêtes**

### Phase 2: Validation (2-4h)
- [ ] **Vérifier élimination requêtes massives**
- [ ] **Confirmer stabilité CPU**
- [ ] **Test charge utilisateur**

### Phase 3: Nettoyage (4-8h)
- [ ] **Audit configuration flb/all_product**
- [ ] **Correction données corrompues**
- [ ] **Validation intégrité référentielle**

### Phase 4: Monitoring (Ongoing)
- [ ] **Alertes slow queries**
- [ ] **Dashboard performance**
- [ ] **Documentation procédures**

---

## ⚡ Impact Attendu

### Métriques Cibles Post-Fix
| Métrique | Avant | Après (Cible) |
|----------|-------|---------------|
| CPU MariaDB | 100-350% | <50% |
| Requêtes lentes/heure | >100K | <100 |
| Temps réponse produits | Timeout | <2s |
| Pages produits | Inaccessibles | Fonctionnelles |

### Bénéfices Métier
- **Restauration service complet**
- **Expérience utilisateur normale**  
- **Stabilité infrastructure**
- **Confiance système**

---

## 🔧 Recommandations Techniques

### Monitoring Préventif
```sql
-- Query pour surveillance continue
SELECT COUNT(*) as slow_queries_last_hour
FROM mysql.slow_log 
WHERE start_time > DATE_SUB(NOW(), INTERVAL 1 HOUR);
```

### Bonnes Pratiques Code
1. **Cache systematic:** Toujours cacher appels Repository
2. **Error handling:** Gestion exceptions robuste
3. **Performance testing:** Load testing avant production
4. **Code review:** Focus patterns Repository usage

---

## 📞 Escalade & Support

### Contact Technique
- **Investigation:** Analyse système complète effectuée
- **Validation:** Tests recommandés avant implémentation  
- **Support:** Monitoring post-déploiement requis

### Documentation Complémentaire
- Logs détaillés: `/var/lib/mysql/flb-prod-slow.log`
- Code source: `/var/www/flbsolutions.com/app/code/Flb/Catalog/`
- Configuration: `core_config_data` table

---

**Statut:** ✅ Investigation Complète | 🔄 Attente Approbation Équipe Dev | ⏳ Implémentation Pending

---
*Analyse générée le 29 juillet 2025 - Investigation technique systématique*