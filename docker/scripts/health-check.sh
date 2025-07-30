#!/bin/bash
# ========================================
# FLB Solutions - Health Check Script
# Validation robuste de l'état du container
# ========================================

set -euo pipefail

# Configuration
HEALTH_PORT=${HEALTH_PORT:-3000}
TIMEOUT=${HEALTH_TIMEOUT:-5}
MAX_RETRIES=${HEALTH_RETRIES:-3}

# Fonction de logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] HEALTH: $1" >&2
}

# Vérifications système
check_system() {
    # Vérification mémoire disponible
    local mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local mem_threshold=500000  # 500MB en KB
    
    if [[ $mem_available -lt $mem_threshold ]]; then
        log "❌ Mémoire insuffisante: ${mem_available}KB disponible"
        return 1
    fi
    
    # Vérification espace disque
    local disk_usage=$(df /app | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log "❌ Espace disque critique: ${disk_usage}% utilisé"
        return 1
    fi
    
    return 0
}

# Vérification des processus critiques
check_processes() {
    # Vérifier si Node.js fonctionne
    if ! pgrep -f "node" > /dev/null; then
        log "❌ Processus Node.js non détecté"
        return 1
    fi
    
    # Vérifier les navigateurs si tests en cours
    if [[ -f "/tmp/tests-running" ]]; then
        if ! pgrep -f "chromium\|firefox\|webkit" > /dev/null; then
            log "⚠️  Tests en cours mais navigateurs non détectés"
            # Non critique - tests peuvent être en phase d'initialisation
        fi
    fi
    
    return 0
}

# Vérification HTTP endpoint
check_http() {
    local url="http://localhost:${HEALTH_PORT}/health"
    local response_code
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" \
        --max-time "$TIMEOUT" \
        "$url" 2>/dev/null || echo "000")
    
    if [[ "$response_code" != "200" ]]; then
        log "❌ Health endpoint inaccessible (HTTP: $response_code)"
        return 1
    fi
    
    return 0
}

# Vérification des fichiers critiques
check_files() {
    local critical_files=(
        "/app/package.json"
        "/app/playwright.config.js"
        "/app/node_modules/@playwright/test"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -e "$file" ]]; then
            log "❌ Fichier critique manquant: $file"
            return 1
        fi
    done
    
    # Vérifier les navigateurs
    if [[ ! -d "/home/flbtest/.cache/ms-playwright" ]]; then
        log "❌ Navigateurs Playwright non installés"
        return 1
    fi
    
    return 0
}

# Vérification Playwright
check_playwright() {
    # Test rapide de Playwright
    local playwright_test
    playwright_test=$(timeout 10s npx playwright --version 2>/dev/null || echo "failed")
    
    if [[ "$playwright_test" == "failed" ]]; then
        log "❌ Playwright non fonctionnel"
        return 1
    fi
    
    return 0
}

# Health check principal avec retry
main() {
    local attempt=1
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        log "🔍 Health check (tentative $attempt/$MAX_RETRIES)..."
        
        # Exécution des vérifications
        if check_system && \
           check_files && \
           check_processes && \
           check_playwright; then
            
            # Si pas de serveur HTTP, juste valider les composants
            if ! check_http 2>/dev/null; then
                log "ℹ️  Serveur HTTP non disponible - mode standalone"
            fi
            
            log "✅ Container en bonne santé"
            exit 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            log "⏳ Échec tentative $attempt - retry dans 2s..."
            sleep 2
        fi
        
        ((attempt++))
    done
    
    log "❌ Health check échoué après $MAX_RETRIES tentatives"
    exit 1
}

# Exécution
main "$@"