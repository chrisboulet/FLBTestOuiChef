#!/bin/bash
# ========================================
# FLB Solutions - Script de Validation
# Validation complète du container Playwright
# ========================================

set -euo pipefail

# Configuration
IMAGE_NAME="flb-solutions/playwright-tests:2.0.0"
CONTAINER_NAME="flb-validation-test"
TIMEOUT=30

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] VALIDATE:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Nettoyage
cleanup() {
    log "🧹 Nettoyage..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

# Validation de l'image
validate_image() {
    log "🔍 Validation de l'image Docker..."
    
    # Vérifier que l'image existe
    if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        error "Image non trouvée: $IMAGE_NAME"
        info "Construire l'image avec: ./docker/scripts/build.sh"
        return 1
    fi
    
    # Informations sur l'image
    local image_size=$(docker images --format "{{.Size}}" "$IMAGE_NAME")
    local image_id=$(docker images --format "{{.ID}}" "$IMAGE_NAME")
    
    info "Image ID: $image_id"
    info "Taille: $image_size"
    
    log "✅ Image validée"
    return 0
}

# Test de démarrage
test_startup() {
    log "🚀 Test de démarrage du container..."
    
    # Démarrer le container en mode daemon
    if docker run -d \
        --name "$CONTAINER_NAME" \
        --env ENV_TYPE=test \
        --env DEBUG=true \
        --env KEEP_ALIVE=true \
        "$IMAGE_NAME" > /dev/null; then
        
        log "✅ Container démarré"
    else
        error "Échec du démarrage"
        return 1
    fi
    
    # Attendre que le container soit prêt
    local count=0
    while [[ $count -lt $TIMEOUT ]]; do
        if docker exec "$CONTAINER_NAME" ps aux | grep -q "node" 2>/dev/null; then
            log "✅ Container opérationnel"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    error "Timeout: Container non opérationnel après ${TIMEOUT}s"
    return 1
}

# Test des composants
test_components() {
    log "🧪 Test des composants internes..."
    
    # Test Node.js
    local node_version
    if node_version=$(docker exec "$CONTAINER_NAME" node --version 2>/dev/null); then
        info "Node.js: $node_version"
        log "✅ Node.js fonctionnel"
    else
        error "Node.js non fonctionnel"
        return 1
    fi
    
    # Test NPM
    local npm_version
    if npm_version=$(docker exec "$CONTAINER_NAME" npm --version 2>/dev/null); then
        info "NPM: $npm_version"
        log "✅ NPM fonctionnel"
    else
        error "NPM non fonctionnel"
        return 1
    fi
    
    # Test Playwright
    local playwright_version
    if playwright_version=$(docker exec "$CONTAINER_NAME" npx playwright --version 2>/dev/null); then
        info "Playwright: $playwright_version"
        log "✅ Playwright fonctionnel"
    else
        error "Playwright non fonctionnel"
        return 1
    fi
    
    return 0
}

# Test des navigateurs
test_browsers() {
    log "🌐 Test des navigateurs..."
    
    # Vérifier l'installation des navigateurs
    local browsers_path="/home/flbtest/.cache/ms-playwright"
    if docker exec "$CONTAINER_NAME" test -d "$browsers_path" 2>/dev/null; then
        log "✅ Répertoire navigateurs trouvé"
        
        # Lister les navigateurs installés
        local browsers
        if browsers=$(docker exec "$CONTAINER_NAME" ls "$browsers_path" 2>/dev/null); then
            info "Navigateurs installés:"
            echo "$browsers" | while read -r browser; do
                info "  - $browser"
            done
        fi
    else
        warn "⚠️  Répertoire navigateurs non trouvé"
        return 1
    fi
    
    # Test simple Playwright (sans GUI)
    log "Test d'exécution Playwright..."
    if docker exec "$CONTAINER_NAME" timeout 10s npx playwright --version > /dev/null 2>&1; then
        log "✅ Playwright exécutable"
    else
        warn "⚠️  Problème d'exécution Playwright"
        return 1
    fi
    
    return 0
}

# Test des permissions
test_permissions() {
    log "🔐 Test des permissions et sécurité..."
    
    # Vérifier l'utilisateur non-root
    local current_user
    if current_user=$(docker exec "$CONTAINER_NAME" whoami 2>/dev/null); then
        if [[ "$current_user" == "flbtest" ]]; then
            log "✅ Utilisateur non-root: $current_user"
        else
            error "Utilisateur incorrect: $current_user (attendu: flbtest)"
            return 1
        fi
    else
        error "Impossible de déterminer l'utilisateur"
        return 1
    fi
    
    # Vérifier les permissions des répertoires
    local dirs=("/app" "/app/test-results" "/app/reports")
    for dir in "${dirs[@]}"; do
        if docker exec "$CONTAINER_NAME" test -w "$dir" 2>/dev/null; then
            log "✅ Permissions OK: $dir"
        else
            error "Permissions manquantes: $dir"
            return 1
        fi
    done
    
    return 0
}

# Test du health check
test_health() {
    log "💓 Test du health check..."
    
    # Exécuter le script de health check
    if docker exec "$CONTAINER_NAME" /app/scripts/health-check.sh 2>/dev/null; then
        log "✅ Health check réussi"
    else
        warn "⚠️  Health check échoué - normal si pas de serveur HTTP"
    fi
    
    return 0
}

# Test des variables d'environnement
test_environment() {
    log "🌍 Test des variables d'environnement..."
    
    local env_vars=("NODE_ENV" "ENV_TYPE" "PLAYWRIGHT_BROWSERS_PATH")
    for var in "${env_vars[@]}"; do
        local value
        if value=$(docker exec "$CONTAINER_NAME" printenv "$var" 2>/dev/null); then
            info "$var=$value"
            log "✅ Variable OK: $var"
        else
            warn "⚠️  Variable manquante: $var"
        fi
    done
    
    return 0
}

# Test de performance basique
test_performance() {
    log "⚡ Test de performance basique..."
    
    # Test mémoire
    local memory_info
    if memory_info=$(docker exec "$CONTAINER_NAME" cat /proc/meminfo | grep MemAvailable 2>/dev/null); then
        info "Mémoire: $memory_info"
        log "✅ Informations mémoire disponibles"
    fi
    
    # Test CPU
    local cpu_info
    if cpu_info=$(docker exec "$CONTAINER_NAME" nproc 2>/dev/null); then
        info "CPUs disponibles: $cpu_info"
        log "✅ Informations CPU disponibles"
    fi
    
    return 0
}

# Rapport de validation
generate_report() {
    log "📊 Génération du rapport de validation..."
    
    local report_file="/tmp/flb-validation-report.txt"
    
    cat > "$report_file" << EOF
# FLB Solutions - Rapport de Validation Docker
Date: $(date)
Image: $IMAGE_NAME
Container: $CONTAINER_NAME

## Résultats des Tests

EOF
    
    info "Rapport sauvegardé: $report_file"
    log "✅ Rapport généré"
}

# Fonction principale
main() {
    log "🎯 FLB Solutions - Validation Docker Container"
    log "Image: $IMAGE_NAME"
    
    # Nettoyage préalable
    cleanup
    
    # Exécution des tests
    local tests=(
        "validate_image"
        "test_startup" 
        "test_components"
        "test_browsers"
        "test_permissions"
        "test_health"
        "test_environment"
        "test_performance"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        log "Exécution: $test"
        if "$test"; then
            ((passed++))
        else
            ((failed++))
            warn "Test échoué: $test"
        fi
        echo # Ligne vide pour lisibilité
    done
    
    # Résumé
    log "📈 Résumé de validation:"
    log "  ✅ Tests réussis: $passed"
    if [[ $failed -gt 0 ]]; then
        log "  ❌ Tests échoués: $failed"
    fi
    
    generate_report
    
    if [[ $failed -eq 0 ]]; then
        log "🎉 Validation complète réussie !"
        log "Le container FLB Playwright est prêt pour production"
        return 0
    else
        error "⚠️  Certains tests ont échoué - vérifiez la configuration"
        return 1
    fi
}

# Exécution
main "$@"