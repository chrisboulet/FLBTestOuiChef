#!/bin/bash
# ========================================
# FLB Solutions - Deploy Script
# Déploiement orchestré multi-environnements
# ========================================

set -euo pipefail

# Configuration des couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration par défaut
ENV=${ENV:-dev}
ACTION=${ACTION:-up}
PROFILE=${PROFILE:-}
SERVICES=${SERVICES:-}
FORCE=${FORCE:-false}
VALIDATE=${VALIDATE:-true}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-120}

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] DEPLOY:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARN:${NC} $1"
}

step() {
    echo -e "${PURPLE}[$(date +'%H:%M:%S')] STEP:${NC} $1"
}

# Validation des prérequis
validate_prerequisites() {
    step "🔍 Validation des prérequis..."
    
    # Docker et Docker Compose
    for tool in docker docker-compose; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool n'est pas installé"
            exit 1
        fi
    done
    
    # Fichiers de configuration
    local required_files=(
        "Dockerfile"
        "docker-compose.yml"
        ".env.example"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Fichier requis manquant: $file"
            exit 1
        fi
    done
    
    # Variables d'environnement
    if [[ ! -f ".env" ]]; then
        if [[ "$ENV" == "prod" ]]; then
            error "Fichier .env requis pour la production"
            exit 1
        else
            warn "Fichier .env manquant - utilisation des valeurs par défaut"
            cp .env.example .env
        fi
    fi
    
    info "✅ Prérequis validés"
}

# Configuration de l'environnement
setup_environment() {
    step "⚙️ Configuration de l'environnement: $ENV"
    
    # Export des variables d'environnement
    export ENV_TYPE="$ENV"
    export COMPOSE_PROJECT_NAME="flb-tests-$ENV"
    export COMPOSE_FILE="docker-compose.yml"
    
    # Configuration du profil Docker Compose
    case "$ENV" in
        "dev")
            export COMPOSE_PROFILES="dev"
            export DEBUG=true
            export HEADLESS=false
            ;;
        "test")
            export COMPOSE_PROFILES="test"
            export DEBUG=false
            export HEADLESS=true
            ;;
        "staging")
            export COMPOSE_PROFILES="staging"
            export DEBUG=false
            export HEADLESS=true
            export SECURITY_SCAN_ENABLED=true
            ;;
        "prod")
            export COMPOSE_PROFILES="prod"
            export DEBUG=false
            export HEADLESS=true
            export SECURITY_SCAN_ENABLED=true
            export VULNERABILITY_THRESHOLD=CRITICAL
            ;;
        *)
            error "Environnement non supporté: $ENV"
            exit 1
            ;;
    esac
    
    # Override du profil si spécifié
    if [[ -n "$PROFILE" ]]; then
        export COMPOSE_PROFILES="$PROFILE"
    fi
    
    info "Configuration: ENV=$ENV, PROFILE=${COMPOSE_PROFILES}, PROJECT=${COMPOSE_PROJECT_NAME}"
}

# Setup des secrets
setup_secrets() {
    step "🔐 Configuration des secrets..."
    
    if [[ -f "docker/secrets/setup-secrets.sh" ]]; then
        if [[ "$ENV" == "prod" ]]; then
            warn "Production: Vérifier que les secrets sont correctement configurés"
            read -p "Les secrets de production sont-ils configurés? (oui/non): " -r
            if [[ ! $REPLY =~ ^(oui|OUI|yes|YES)$ ]]; then
                error "Configuration des secrets de production requise"
                exit 1
            fi
        else
            info "Génération automatique des secrets pour $ENV"
            bash docker/secrets/setup-secrets.sh "$ENV"
        fi
    else
        warn "Script de setup des secrets non trouvé - utilisation des valeurs par défaut"
    fi
}

# Build des images
build_images() {
    if [[ "$ACTION" == "build" ]] || [[ "$ACTION" == "up" ]]; then
        step "🏗️ Construction des images..."
        
        local build_args=""
        
        # Arguments spécifiques à l'environnement
        case "$ENV" in
            "dev")
                build_args="--parallel"
                ;;
            "prod")
                build_args="--no-cache"
                ;;
        esac
        
        if docker-compose build $build_args; then
            info "✅ Images construites avec succès"
        else
            error "❌ Échec de construction des images"
            exit 1
        fi
    fi
}

# Validation de la santé des services
validate_services_health() {
    if [[ "$VALIDATE" == "true" ]]; then
        step "🏥 Validation de la santé des services..."
        
        local timeout=$WAIT_TIMEOUT
        local interval=5
        local elapsed=0
        
        while [[ $elapsed -lt $timeout ]]; do
            local healthy_services=0
            local total_services=0
            
            # Vérification de chaque service
            while IFS= read -r service; do
                if [[ -n "$service" ]]; then
                    total_services=$((total_services + 1))
                    
                    local health_status
                    health_status=$(docker-compose ps --format json "$service" 2>/dev/null | jq -r '.Health // "unknown"' 2>/dev/null || echo "unknown")
                    
                    case "$health_status" in
                        "healthy")
                            healthy_services=$((healthy_services + 1))
                            ;;
                        "starting")
                            info "Service $service en cours de démarrage..."
                            ;;
                        "unhealthy")
                            warn "Service $service non sain"
                            ;;
                        *)
                            # Vérification alternative si pas de health check
                            if docker-compose ps "$service" | grep -q "Up"; then
                                healthy_services=$((healthy_services + 1))
                            fi
                            ;;
                    esac
                fi
            done < <(docker-compose ps --services)
            
            if [[ $healthy_services -eq $total_services ]] && [[ $total_services -gt 0 ]]; then
                info "✅ Tous les services sont sains ($healthy_services/$total_services)"
                return 0
            fi
            
            info "Services sains: $healthy_services/$total_services - Attente..."
            sleep $interval
            elapsed=$((elapsed + interval))
        done
        
        error "❌ Timeout: Services non sains après ${timeout}s"
        
        # Affichage des logs pour diagnostic
        warn "Logs des services pour diagnostic:"
        docker-compose logs --tail=50
        
        if [[ "$FORCE" != "true" ]]; then
            exit 1
        else
            warn "Poursuite forcée malgré les services non sains"
        fi
    fi
}

# Exécution des tests de smoke
run_smoke_tests() {
    if [[ "$ACTION" == "up" ]] && [[ "$ENV" != "prod" ]]; then
        step "💨 Exécution des tests de smoke..."
        
        if docker-compose exec -T playwright-tests npm run test:smoke; then
            info "✅ Tests de smoke réussis"
        else
            warn "⚠️ Tests de smoke échoués - vérifier la configuration"
            
            if [[ "$ENV" == "staging" ]]; then
                error "Tests de smoke requis pour staging"
                exit 1
            fi
        fi
    fi
}

# Affichage du statut des services
show_status() {
    step "📊 Statut des services:"
    
    echo ""
    docker-compose ps
    echo ""
    
    # URLs d'accès
    info "🌐 URLs d'accès:"
    case "$ENV" in
        "dev")
            info "  - Tests: http://localhost (si nginx configuré)"
            info "  - Rapports: http://localhost/reports"
            ;;
        "staging"|"prod")
            info "  - Dashboard: https://localhost/grafana"
            info "  - Métriques: https://localhost/prometheus"
            info "  - Rapports: https://localhost/reports"
            ;;
    esac
    
    # Commandes utiles
    info "🔧 Commandes utiles:"
    info "  - Logs: docker-compose logs -f [service]"
    info "  - Shell: docker-compose exec [service] /bin/bash"
    info "  - Tests: docker-compose exec playwright-tests npm run test"
    info "  - Arrêt: docker-compose down"
}

# Nettoyage des ressources
cleanup_resources() {
    step "🧹 Nettoyage des ressources..."
    
    # Arrêt propre des services
    docker-compose down --remove-orphans
    
    # Nettoyage des volumes orphelins si demandé
    if [[ "$FORCE" == "true" ]]; then
        warn "Nettoyage forcé des volumes..."
        docker-compose down -v
        docker system prune -f
    fi
    
    info "✅ Nettoyage terminé"
}

# Gestion des actions
execute_action() {
    case "$ACTION" in
        "up")
            build_images
            
            step "🚀 Démarrage des services..."
            if [[ -n "$SERVICES" ]]; then
                docker-compose up -d $SERVICES
            else
                docker-compose --profile "$COMPOSE_PROFILES" up -d
            fi
            
            validate_services_health
            run_smoke_tests
            show_status
            ;;
            
        "down")
            step "⬇️ Arrêt des services..."
            cleanup_resources
            ;;
            
        "restart")
            step "🔄 Redémarrage des services..."
            docker-compose restart $SERVICES
            validate_services_health
            show_status
            ;;
            
        "build")
            build_images
            ;;
            
        "logs")
            step "📋 Affichage des logs..."
            if [[ -n "$SERVICES" ]]; then
                docker-compose logs -f $SERVICES
            else
                docker-compose logs -f
            fi
            ;;
            
        "status")
            show_status
            ;;
            
        "test")
            step "🧪 Exécution des tests..."
            docker-compose exec playwright-tests npm run test
            ;;
            
        "clean")
            step "🧹 Nettoyage complet..."
            docker-compose down -v --remove-orphans
            docker system prune -af
            info "✅ Nettoyage complet terminé"
            ;;
            
        *)
            error "Action non supportée: $ACTION"
            show_help
            exit 1
            ;;
    esac
}

# Affichage de l'aide
show_help() {
    cat << EOF
🚀 FLB Solutions - Script de Déploiement Docker

Usage: $0 [OPTIONS] ACTION

Actions:
    up          Démarrer les services (défaut)
    down        Arrêter les services
    restart     Redémarrer les services
    build       Construire les images uniquement
    logs        Afficher les logs
    status      Afficher le statut des services
    test        Exécuter les tests
    clean       Nettoyage complet

Options:
    -e, --env ENV           Environnement (dev|test|staging|prod) [default: dev]
    -p, --profile PROFILE   Profil Docker Compose à utiliser
    -s, --services SERVICES Services spécifiques à gérer
    -f, --force             Forcer l'exécution même en cas d'erreurs
    --no-validate           Désactiver la validation des services
    --timeout SECONDS       Timeout pour la validation [default: 120]
    -h, --help              Afficher cette aide

Exemples:
    $0 up                                    # Démarrage développement
    $0 -e test up                           # Démarrage tests
    $0 -e staging -p staging up             # Démarrage staging complet
    $0 -e prod --timeout 300 up             # Démarrage production avec timeout
    $0 -s playwright-tests restart          # Redémarrage service spécifique
    $0 logs                                 # Logs de tous les services
    $0 -s grafana logs                      # Logs du service Grafana
    $0 clean                                # Nettoyage complet

Variables d'environnement:
    ENV                 Environnement cible
    ACTION              Action à exécuter
    PROFILE             Profil Docker Compose
    SERVICES            Services spécifiques
    FORCE               Forcer l'exécution (true/false)
    VALIDATE            Validation des services (true/false)
    WAIT_TIMEOUT        Timeout de validation (secondes)

Profils disponibles:
    dev                 Services essentiels pour développement
    test                Services avec monitoring basique
    staging             Services complets avec monitoring
    prod                Services production avec sécurité renforcée
EOF
}

# Parsing des arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENV="$2"
                shift 2
                ;;
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -s|--services)
                SERVICES="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --no-validate)
                VALIDATE=false
                shift
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            up|down|restart|build|logs|status|test|clean)
                ACTION="$1"
                shift
                ;;
            *)
                error "Argument inconnu: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Gestion des signaux
cleanup_on_signal() {
    warn "Signal reçu - arrêt en cours..."
    cleanup_resources
    exit 130
}

trap cleanup_on_signal SIGINT SIGTERM

# Point d'entrée principal
main() {
    log "🚀 FLB Solutions - Déploiement Docker"
    log "Environment: $ENV | Action: $ACTION | Profile: ${PROFILE:-auto}"
    
    validate_prerequisites
    setup_environment
    setup_secrets
    execute_action
    
    log "✅ Déploiement $ACTION terminé avec succès!"
}

# Exécution
parse_arguments "$@"
main