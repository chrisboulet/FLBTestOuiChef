#!/bin/bash

# ========================================
# Script de Documentation des Preuves
# Problème Performance Magento 2.4.7 + MariaDB
# Date: 29 juillet 2025
# ========================================

# Configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EVIDENCE_DIR="/tmp/magento_evidence_${TIMESTAMP}"
LOG_FILE="${EVIDENCE_DIR}/evidence_collection.log"
MYSQL_SLOW_LOG="/var/lib/mysql/flb-prod-slow.log"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction d'erreur
error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

# Fonction de succès
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

# Fonction d'info
info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

# Fonction d'avertissement
warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOG_FILE"
}

# Création du répertoire de preuves
create_evidence_dir() {
    log "=== DÉBUT COLLECTE PREUVES ==="
    mkdir -p "$EVIDENCE_DIR"
    info "Répertoire créé: $EVIDENCE_DIR"
}

# 1. Collecte informations système
collect_system_info() {
    log "1. Collecte informations système..."
    
    # CPU et mémoire
    echo "=== INFORMATIONS SYSTÈME ===" > "${EVIDENCE_DIR}/01_system_info.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/01_system_info.txt"
    echo "" >> "${EVIDENCE_DIR}/01_system_info.txt"
    
    echo "--- CPU Usage ---" >> "${EVIDENCE_DIR}/01_system_info.txt"
    top -bn1 | grep "Cpu(s)" >> "${EVIDENCE_DIR}/01_system_info.txt"
    echo "" >> "${EVIDENCE_DIR}/01_system_info.txt"
    
    echo "--- Memory Usage ---" >> "${EVIDENCE_DIR}/01_system_info.txt"
    free -h >> "${EVIDENCE_DIR}/01_system_info.txt"
    echo "" >> "${EVIDENCE_DIR}/01_system_info.txt"
    
    echo "--- Load Average ---" >> "${EVIDENCE_DIR}/01_system_info.txt"
    uptime >> "${EVIDENCE_DIR}/01_system_info.txt"
    
    success "Informations système collectées"
}

# 2. Analyse processus MariaDB
collect_mysql_processes() {
    log "2. Collecte processus MariaDB actifs..."
    
    echo "=== PROCESSUS MYSQL ACTIFS ===" > "${EVIDENCE_DIR}/02_mysql_processes.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/02_mysql_processes.txt"
    echo "" >> "${EVIDENCE_DIR}/02_mysql_processes.txt"
    
    mysql -e "SHOW FULL PROCESSLIST;" >> "${EVIDENCE_DIR}/02_mysql_processes.txt" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        success "Processus MySQL collectés"
    else
        error "Impossible de se connecter à MySQL - vérifier les credentials"
    fi
}

# 3. Analyse requêtes lentes
collect_slow_queries() {
    log "3. Analyse requêtes lentes..."
    
    echo "=== ANALYSE REQUÊTES LENTES ===" > "${EVIDENCE_DIR}/03_slow_queries.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    echo "" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    
    # Compter les requêtes lentes
    echo "--- Comptage total requêtes lentes ---" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    mysql -e "SELECT COUNT(*) as total_slow_queries FROM mysql.slow_log;" >> "${EVIDENCE_DIR}/03_slow_queries.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    
    # Top 10 des requêtes les plus lentes
    echo "--- Top 10 requêtes les plus lentes ---" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    mysql -e "SELECT sql_text, query_time, rows_examined, start_time FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;" >> "${EVIDENCE_DIR}/03_slow_queries.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    
    # Recherche des entités problématiques (1331, 2047)
    echo "--- Requêtes impliquant entity_id 1331 ---" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    mysql -e "SELECT COUNT(*) as count_1331 FROM mysql.slow_log WHERE sql_text LIKE '%1331%';" >> "${EVIDENCE_DIR}/03_slow_queries.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    
    echo "--- Requêtes impliquant entity_id 2047 ---" >> "${EVIDENCE_DIR}/03_slow_queries.txt"
    mysql -e "SELECT COUNT(*) as count_2047 FROM mysql.slow_log WHERE sql_text LIKE '%2047%';" >> "${EVIDENCE_DIR}/03_slow_queries.txt" 2>/dev/null
    
    success "Analyse requêtes lentes terminée"
}

# 4. Vérification entités problématiques
verify_entities() {
    log "4. Vérification des entités 1331 et 2047..."
    
    echo "=== VÉRIFICATION ENTITÉS ===" > "${EVIDENCE_DIR}/04_entity_verification.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    echo "" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    
    # Vérifier si ce sont des catégories
    echo "--- Vérification entités dans catalog_category_entity ---" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    mysql -e "SELECT entity_id, entity_type_id, created_at, updated_at FROM catalog_category_entity WHERE entity_id IN (1331, 2047);" >> "${EVIDENCE_DIR}/04_entity_verification.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    
    # Vérifier si elles existent dans catalog_product_entity
    echo "--- Vérification entités dans catalog_product_entity ---" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    mysql -e "SELECT entity_id, entity_type_id, created_at, updated_at FROM catalog_product_entity WHERE entity_id IN (1331, 2047);" >> "${EVIDENCE_DIR}/04_entity_verification.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    
    # Types d'entités
    echo "--- Types d'entités ---" >> "${EVIDENCE_DIR}/04_entity_verification.txt"
    mysql -e "SELECT entity_type_id, entity_type_code, entity_model FROM eav_entity_type WHERE entity_type_code IN ('catalog_category', 'catalog_product');" >> "${EVIDENCE_DIR}/04_entity_verification.txt" 2>/dev/null
    
    success "Vérification entités terminée"
}

# 5. Analyse configuration Magento
collect_magento_config() {
    log "5. Collecte configuration Magento..."
    
    echo "=== CONFIGURATION MAGENTO ===" > "${EVIDENCE_DIR}/05_magento_config.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/05_magento_config.txt"
    echo "" >> "${EVIDENCE_DIR}/05_magento_config.txt"
    
    # Configuration flb/all_product/category_id
    echo "--- Configuration flb/all_product/category_id ---" >> "${EVIDENCE_DIR}/05_magento_config.txt"
    mysql -e "SELECT * FROM core_config_data WHERE path = 'flb/all_product/category_id';" >> "${EVIDENCE_DIR}/05_magento_config.txt" 2>/dev/null
    echo "" >> "${EVIDENCE_DIR}/05_magento_config.txt"
    
    # Status indexeurs
    echo "--- Status indexeurs ---" >> "${EVIDENCE_DIR}/05_magento_config.txt"
    mysql -e "SELECT * FROM indexer_state;" >> "${EVIDENCE_DIR}/05_magento_config.txt" 2>/dev/null
    
    success "Configuration Magento collectée"
}

# 6. Analyse du code source BrandAttribute.php
analyze_source_code() {
    log "6. Analyse code source BrandAttribute.php..."
    
    BRAND_ATTR_FILE="/var/www/flbsolutions.com/app/code/Flb/Catalog/ViewModel/BrandAttribute.php"
    
    echo "=== ANALYSE CODE SOURCE ===" > "${EVIDENCE_DIR}/06_source_code.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/06_source_code.txt"
    echo "" >> "${EVIDENCE_DIR}/06_source_code.txt"
    
    if [ -f "$BRAND_ATTR_FILE" ]; then
        echo "--- Contenu BrandAttribute.php ---" >> "${EVIDENCE_DIR}/06_source_code.txt"
        cat "$BRAND_ATTR_FILE" >> "${EVIDENCE_DIR}/06_source_code.txt"
        echo "" >> "${EVIDENCE_DIR}/06_source_code.txt"
        
        # Recherche méthodes problématiques
        echo "--- Méthodes identifiées ---" >> "${EVIDENCE_DIR}/06_source_code.txt"
        grep -n "function.*Category\|function.*Brand" "$BRAND_ATTR_FILE" >> "${EVIDENCE_DIR}/06_source_code.txt" 2>/dev/null
        
        success "Code source analysé"
    else
        error "Fichier BrandAttribute.php non trouvé: $BRAND_ATTR_FILE"
    fi
    
    # Templates utilisant BrandAttribute
    echo "" >> "${EVIDENCE_DIR}/06_source_code.txt"
    echo "--- Templates utilisant BrandAttribute ---" >> "${EVIDENCE_DIR}/06_source_code.txt"
    
    TEMPLATE1="/var/www/flbsolutions.com/app/code/Flb/Catalog/view/frontend/templates/product/list/items.phtml"
    TEMPLATE2="/var/www/flbsolutions.com/app/code/Flb/Catalog/view/frontend/templates/product/view/brand_attribute.phtml"
    
    for template in "$TEMPLATE1" "$TEMPLATE2"; do
        if [ -f "$template" ]; then
            echo "--- $(basename $template) ---" >> "${EVIDENCE_DIR}/06_source_code.txt"
            grep -n "getBrandUrl\|brandViewModel" "$template" >> "${EVIDENCE_DIR}/06_source_code.txt" 2>/dev/null
            echo "" >> "${EVIDENCE_DIR}/06_source_code.txt"
        fi
    done
}

# 7. Collecte métriques performance
collect_performance_metrics() {
    log "7. Collecte métriques performance..."
    
    echo "=== MÉTRIQUES PERFORMANCE ===" > "${EVIDENCE_DIR}/07_performance.txt"
    echo "Date collecte: $(date)" >> "${EVIDENCE_DIR}/07_performance.txt"
    echo "" >> "${EVIDENCE_DIR}/07_performance.txt"
    
    # Processus MySQL utilisant le plus de CPU
    echo "--- Top processus MySQL par CPU ---" >> "${EVIDENCE_DIR}/07_performance.txt"
    ps aux | grep mysql | grep -v grep >> "${EVIDENCE_DIR}/07_performance.txt"
    echo "" >> "${EVIDENCE_DIR}/07_performance.txt"
    
    # Variables MySQL importantes
    echo "--- Variables MySQL clés ---" >> "${EVIDENCE_DIR}/07_performance.txt"
    mysql -e "SHOW VARIABLES LIKE 'slow_query_log%';" >> "${EVIDENCE_DIR}/07_performance.txt" 2>/dev/null
    mysql -e "SHOW VARIABLES LIKE 'long_query_time';" >> "${EVIDENCE_DIR}/07_performance.txt" 2>/dev/null
    mysql -e "SHOW VARIABLES LIKE 'query_cache%';" >> "${EVIDENCE_DIR}/07_performance.txt" 2>/dev/null
    
    success "Métriques performance collectées"
}

# 8. Copie des logs importants
backup_important_logs() {
    log "8. Copie logs importants..."
    
    # Slow query log (dernières 1000 lignes)
    if [ -f "$MYSQL_SLOW_LOG" ]; then
        tail -1000 "$MYSQL_SLOW_LOG" > "${EVIDENCE_DIR}/08_slow_query_sample.log"
        success "Échantillon slow query log copié"
    else
        warn "Slow query log non trouvé: $MYSQL_SLOW_LOG"
    fi
    
    # Logs Magento
    MAGENTO_LOG_DIR="/var/www/flbsolutions.com/var/log"
    if [ -d "$MAGENTO_LOG_DIR" ]; then
        # Exception log
        if [ -f "$MAGENTO_LOG_DIR/exception.log" ]; then
            tail -500 "$MAGENTO_LOG_DIR/exception.log" > "${EVIDENCE_DIR}/08_magento_exception.log"
        fi
        
        # System log  
        if [ -f "$MAGENTO_LOG_DIR/system.log" ]; then
            tail -500 "$MAGENTO_LOG_DIR/system.log" > "${EVIDENCE_DIR}/08_magento_system.log"
        fi
        
        success "Logs Magento copiés"
    else
        warn "Répertoire logs Magento non trouvé: $MAGENTO_LOG_DIR"
    fi
}

# 9. Génération rapport de synthèse
generate_summary_report() {
    log "9. Génération rapport de synthèse..."
    
    SUMMARY_FILE="${EVIDENCE_DIR}/00_RAPPORT_SYNTHESE.md"
    
    cat > "$SUMMARY_FILE" << EOF
# Rapport de Synthèse - Collecte Preuves Magento
**Date:** $(date)  
**Répertoire:** $EVIDENCE_DIR  

## 🎯 Résumé Exécutif
Investigation technique automatisée du problème de performance Magento 2.4.7 + MariaDB.

## 📁 Fichiers Générés
1. **01_system_info.txt** - Informations système (CPU, mémoire, charge)
2. **02_mysql_processes.txt** - Processus MariaDB actifs
3. **03_slow_queries.txt** - Analyse requêtes lentes et entités 1331/2047
4. **04_entity_verification.txt** - Vérification types entités
5. **05_magento_config.txt** - Configuration Magento et indexeurs
6. **06_source_code.txt** - Analyse BrandAttribute.php et templates
7. **07_performance.txt** - Métriques performance et variables MySQL
8. **08_*.log** - Échantillons logs importants

## 🔍 Points Clés à Vérifier
- [ ] Comptage requêtes lentes pour entities 1331 et 2047
- [ ] Confirmation que 1331/2047 sont des catégories, pas des produits
- [ ] Configuration flb/all_product/category_id corrompue
- [ ] Absence de cache dans getCategoryUrl() de BrandAttribute.php
- [ ] Appels répétés dans templates product/list/items.phtml

## 📊 Métriques Attendues
- **Requêtes 1331:** ~21,030 occurrences
- **Requêtes 2047:** ~13,570 occurrences  
- **CPU MySQL:** 100-350%
- **Total slow queries:** >2M

## 🚀 Utilisation
\`\`\`bash
# Analyser les résultats
grep -i "count_1331\|count_2047" 03_slow_queries.txt
grep -i "entity_id.*1331\|entity_id.*2047" 04_entity_verification.txt
grep -n "getCategoryUrl\|categoryRepository" 06_source_code.txt
\`\`\`

---
*Collecte automatisée - Script evidence v1.0*
EOF

    success "Rapport de synthèse généré: $SUMMARY_FILE"
}

# 10. Archive et nettoyage
create_archive() {
    log "10. Création archive..."
    
    cd /tmp
    tar -czf "magento_evidence_${TIMESTAMP}.tar.gz" "magento_evidence_${TIMESTAMP}/"
    
    if [ $? -eq 0 ]; then
        success "Archive créée: /tmp/magento_evidence_${TIMESTAMP}.tar.gz"
        info "Taille archive: $(du -h /tmp/magento_evidence_${TIMESTAMP}.tar.gz | cut -f1)"
    else
        error "Échec création archive"
    fi
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  COLLECTE PREUVES MAGENTO PERFORMANCE"
    echo "========================================"
    echo -e "${NC}"
    
    create_evidence_dir
    collect_system_info
    collect_mysql_processes  
    collect_slow_queries
    verify_entities
    collect_magento_config
    analyze_source_code
    collect_performance_metrics
    backup_important_logs
    generate_summary_report
    create_archive
    
    echo ""
    log "=== COLLECTE TERMINÉE ==="
    success "Répertoire: $EVIDENCE_DIR"
    success "Archive: /tmp/magento_evidence_${TIMESTAMP}.tar.gz"
    success "Rapport: ${EVIDENCE_DIR}/00_RAPPORT_SYNTHESE.md"
    
    echo ""
    info "Commandes utiles pour analyse:"
    echo -e "${YELLOW}  cat ${EVIDENCE_DIR}/00_RAPPORT_SYNTHESE.md${NC}"
    echo -e "${YELLOW}  grep -i 'count_1331\\|count_2047' ${EVIDENCE_DIR}/03_slow_queries.txt${NC}"
    echo -e "${YELLOW}  tar -xzf /tmp/magento_evidence_${TIMESTAMP}.tar.gz${NC}"
}

# Vérification droits root
if [ "$EUID" -ne 0 ]; then 
    warn "Ce script devrait être exécuté en tant que root pour un accès complet aux logs"
    warn "Certaines collectes peuvent échouer..."
    echo ""
fi

# Exécution
main "$@"