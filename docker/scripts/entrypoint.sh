#!/bin/bash
# ========================================
# FLB Solutions - Entrypoint Script
# Gestion des signaux et orchestration des tests
# ========================================

set -euo pipefail

# Configuration des couleurs pour logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration par défaut
NODE_ENV=${NODE_ENV:-test}
ENV_TYPE=${ENV_TYPE:-dev}
DEBUG=${DEBUG:-false}
PARALLEL_WORKERS=${PARALLEL_WORKERS:-4}
HEADLESS=${HEADLESS:-true}

# Fonction de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] FLB-TESTS:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG:${NC} $1"
    fi
}

# Fonction de nettoyage
cleanup() {
    log "🧹 Nettoyage des ressources..."
    
    # Arrêter les processus en arrière-plan
    if [[ -n "${BACKGROUND_PID:-}" ]]; then
        kill -TERM "$BACKGROUND_PID" 2>/dev/null || true
        wait "$BACKGROUND_PID" 2>/dev/null || true
    fi
    
    # Sauvegarder les résultats
    if [[ -d "/app/test-results" ]]; then
        log "💾 Sauvegarde des résultats de tests..."
        tar -czf "/app/reports/test-results-$(date +%Y%m%d-%H%M%S).tar.gz" -C "/app" test-results/
    fi
    
    log "✅ Nettoyage terminé"
    exit 0
}

# Configuration des signaux
trap cleanup SIGTERM SIGINT SIGQUIT

# Validation de l'environnement
validate_environment() {
    log "🔍 Validation de l'environnement $ENV_TYPE..."
    
    # Vérification des secrets
    if [[ ! -f "/app/config/credentials.json" ]]; then
        error "❌ Fichier credentials.json manquant"
        exit 1
    fi
    
    # Vérification des navigateurs
    if [[ ! -d "/opt/playwright-browsers" ]]; then
        error "❌ Navigateurs Playwright non installés"
        exit 1
    fi
    
    # Vérification de la connectivité
    if ! curl -s --connect-timeout 5 "${BASE_URL:-https://www.flbsolutions.com}" > /dev/null; then
        warn "⚠️  Site FLB Solutions non accessible - mode offline activé"
        export OFFLINE_MODE=true
    fi
    
    log "✅ Environnement validé"
}

# Configuration spécifique par environnement
configure_environment() {
    log "⚙️  Configuration pour environnement: $ENV_TYPE"
    
    case "$ENV_TYPE" in
        "dev")
            export HEADLESS=false
            export PARALLEL_WORKERS=2
            export SCREENSHOT_MODE=on
            ;;
        "test")
            export HEADLESS=true
            export PARALLEL_WORKERS=4
            export SCREENSHOT_MODE=only-on-failure
            ;;
        "staging")
            export HEADLESS=true
            export PARALLEL_WORKERS=6
            export SCREENSHOT_MODE=only-on-failure
            export RETRY_FAILED=2
            ;;
        "prod")
            export HEADLESS=true
            export PARALLEL_WORKERS=8
            export SCREENSHOT_MODE=never
            export RETRY_FAILED=3
            ;;
    esac
    
    debug "Configuration appliquée: workers=$PARALLEL_WORKERS, headless=$HEADLESS"
}

# Health check endpoint
start_health_server() {
    if [[ "$ENV_TYPE" != "dev" ]]; then
        log "🏥 Démarrage du serveur de santé..."
        cat > /tmp/health-server.js << 'EOF'
const http = require('http');
const fs = require('fs');

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        const status = fs.existsSync('/tmp/tests-running') ? 200 : 503;
        res.writeHead(status, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
            status: status === 200 ? 'healthy' : 'unhealthy',
            timestamp: new Date().toISOString(),
            environment: process.env.ENV_TYPE
        }));
    } else {
        res.writeHead(404);
        res.end('Not Found');
    }
});

server.listen(3000, () => {
    console.log('Health server running on port 3000');
});
EOF
        node /tmp/health-server.js &
        BACKGROUND_PID=$!
    fi
}

# Exécution des tests
run_tests() {
    log "🚀 Démarrage des tests FLB Solutions..."
    
    # Marquer les tests comme en cours
    touch /tmp/tests-running
    
    # Configuration des options Playwright
    PLAYWRIGHT_OPTS=""
    
    if [[ "$HEADLESS" == "true" ]]; then
        PLAYWRIGHT_OPTS="$PLAYWRIGHT_OPTS --workers=$PARALLEL_WORKERS"
    else
        PLAYWRIGHT_OPTS="$PLAYWRIGHT_OPTS --headed --workers=1"
    fi
    
    if [[ -n "${RETRY_FAILED:-}" ]]; then
        PLAYWRIGHT_OPTS="$PLAYWRIGHT_OPTS --retries=$RETRY_FAILED"
    fi
    
    # Exécution basée sur les arguments
    case "${1:-test}" in
        "smoke")
            log "💨 Exécution des tests smoke..."
            npx playwright test tests/smoke/ $PLAYWRIGHT_OPTS
            ;;
        "regression")
            log "🔄 Exécution des tests de régression..."
            npx playwright test $PLAYWRIGHT_OPTS
            ;;
        "critical")
            log "🚨 Exécution des tests critiques..."
            npx playwright test tests/critical/ $PLAYWRIGHT_OPTS
            ;;
        "auth")
            log "🔐 Exécution des tests d'authentification..."
            npx playwright test tests/smoke/flb-authenticated.spec.js $PLAYWRIGHT_OPTS
            ;;
        *)
            log "📋 Exécution de la suite complète..."
            npx playwright test $PLAYWRIGHT_OPTS
            ;;
    esac
    
    # Marquer les tests comme terminés
    rm -f /tmp/tests-running
}

# Génération du rapport
generate_report() {
    log "📊 Génération du rapport..."
    
    if [[ -d "/app/test-results" ]]; then
        npx playwright show-report --host=0.0.0.0 --port=9323 &
        REPORT_PID=$!
        
        # Attendre que le rapport soit généré
        sleep 5
        
        # Copier le rapport dans le volume partagé
        if [[ -d "/app/playwright-report" ]]; then
            cp -r /app/playwright-report/* /app/reports/ 2>/dev/null || true
        fi
        
        kill $REPORT_PID 2>/dev/null || true
    fi
}

# Point d'entrée principal
main() {
    log "🎯 FLB Solutions Test Suite - Starting..."
    log "Environment: $ENV_TYPE | Node: $NODE_ENV | Workers: $PARALLEL_WORKERS"
    
    # Initialisation
    validate_environment
    configure_environment
    start_health_server
    
    # Exécution
    run_tests "$@"
    
    # Post-traitement
    generate_report
    
    log "✅ Tests terminés avec succès"
    
    # Maintenir le conteneur actif si demandé
    if [[ "${KEEP_ALIVE:-false}" == "true" ]]; then
        log "💤 Mode keep-alive activé - conteneur maintenu actif"
        tail -f /dev/null
    fi
}

# Exécution
main "$@"