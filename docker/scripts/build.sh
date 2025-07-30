#!/bin/bash
# ========================================
# FLB Solutions - Script de Build Optimisé
# Construction et validation des images Docker
# ========================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMAGE_NAME="flb-solutions/playwright-tests"
VERSION="2.0.0"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}

# Couleurs pour logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction de logging
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] BUILD:${NC} $1"
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

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -t, --target TARGET     Build target (default: production)
    -v, --version VERSION   Image version (default: $VERSION)
    -n, --no-cache         Build without cache
    -p, --push             Push to registry after build
    -c, --clean            Clean before build
    -s, --scan             Security scan with Trivy
    -d, --dev              Development build with debug
    -h, --help             Show this help

Examples:
    $0                      # Build standard
    $0 --no-cache --scan    # Build clean avec scan sécurité
    $0 --dev                # Build développement
    $0 --push               # Build et push registry

Targets disponibles:
    - base                  # Base avec Node.js
    - dependencies          # Avec dépendances NPM
    - browsers              # Avec navigateurs
    - runtime               # Runtime complet
    - production (default)  # Image finale

EOF
}

# Validation de l'environnement
validate_environment() {
    log "🔍 Validation de l'environnement..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        error "Docker n'est pas installé"
        exit 1
    fi
    
    # Vérifier les fichiers requis
    local required_files=(
        "$PROJECT_DIR/Dockerfile.optimized"
        "$PROJECT_DIR/package.json"
        "$PROJECT_DIR/playwright.config.js"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Fichier requis manquant: $file"
            exit 1
        fi
    done
    
    # Vérifier l'espace disque
    local available_space=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    local required_space=5000000  # 5GB en KB
    
    if [[ $available_space -lt $required_space ]]; then
        error "Espace disque insuffisant: $(($available_space / 1024 / 1024))GB disponible, 5GB requis"
        exit 1
    fi
    
    log "✅ Environnement validé"
}

# Nettoyage avant build
clean_build() {
    log "🧹 Nettoyage des images et cache..."
    
    # Supprimer les images existantes
    docker rmi "$IMAGE_NAME:$VERSION" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:latest" 2>/dev/null || true
    
    # Nettoyer les images intermédiaires
    docker image prune -f --filter "label=stage=browsers-installation"
    docker image prune -f --filter "label=stage=production"
    
    # Nettoyer le cache de build
    docker builder prune -f
    
    log "✅ Nettoyage terminé"
}

# Construction de l'image
build_image() {
    local target="$1"
    local no_cache="$2"
    local dev_mode="$3"
    
    log "🏗️  Construction de l'image '$IMAGE_NAME:$VERSION' (target: $target)..."
    
    # Options de build
    local build_args=(
        "--file" "$PROJECT_DIR/Dockerfile.optimized"
        "--target" "$target"
        "--tag" "$IMAGE_NAME:$VERSION"
        "--tag" "$IMAGE_NAME:latest"
        "--build-arg" "GIT_COMMIT=$GIT_COMMIT"
        "--build-arg" "BUILD_DATE=$BUILD_DATE"
        "--label" "com.flb.build.version=$VERSION"
        "--label" "com.flb.build.date=$BUILD_DATE"
        "--label" "com.flb.build.revision=$GIT_COMMIT"
    )
    
    # Mode développement
    if [[ "$dev_mode" == "true" ]]; then
        build_args+=(
            "--build-arg" "NODE_ENV=development"
            "--build-arg" "DEBUG=true"
            "--tag" "$IMAGE_NAME:dev"
        )
    fi
    
    # No cache
    if [[ "$no_cache" == "true" ]]; then
        build_args+=("--no-cache")
    fi
    
    # Affichage de la commande
    info "Docker build command:"
    echo "docker build ${build_args[*]} $PROJECT_DIR"
    
    # Construction
    if docker build "${build_args[@]}" "$PROJECT_DIR"; then
        log "✅ Image construite avec succès"
        
        # Afficher les informations de l'image
        local image_size=$(docker images --format "table {{.Size}}" "$IMAGE_NAME:$VERSION" | tail -n1)
        local image_id=$(docker images --format "table {{.ID}}" "$IMAGE_NAME:$VERSION" | tail -n1)
        
        info "Image ID: $image_id"
        info "Taille: $image_size"
        
        return 0
    else
        error "Échec de la construction"
        return 1
    fi
}

# Test de l'image
test_image() {
    log "🧪 Test de l'image construite..."
    
    # Test de base - démarrage du container
    if docker run --rm --name flb-test-temp "$IMAGE_NAME:$VERSION" node --version > /dev/null; then
        log "✅ Test de base réussi"
    else
        error "Échec du test de base"
        return 1
    fi
    
    # Test Playwright
    if docker run --rm --name flb-test-playwright "$IMAGE_NAME:$VERSION" npx playwright --version > /dev/null; then
        log "✅ Test Playwright réussi"
    else
        error "Échec du test Playwright"
        return 1
    fi
    
    # Test des navigateurs (rapide)
    if docker run --rm --name flb-test-browsers "$IMAGE_NAME:$VERSION" \
        bash -c "ls /home/flbtest/.cache/ms-playwright && echo 'Navigateurs OK'"; then
        log "✅ Test des navigateurs réussi"
    else
        warn "⚠️  Navigateurs potentiellement manquants"
    fi
    
    return 0
}

# Scan de sécurité avec Trivy
security_scan() {
    log "🛡️  Scan de sécurité avec Trivy..."
    
    if ! command -v trivy &> /dev/null; then
        warn "Trivy non installé - scan de sécurité ignoré"
        return 0
    fi
    
    # Scan des vulnérabilités
    local scan_result
    if scan_result=$(trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE_NAME:$VERSION" 2>&1); then
        log "✅ Scan de sécurité : aucune vulnérabilité critique"
    else
        error "❌ Vulnérabilités détectées:"
        echo "$scan_result"
        return 1
    fi
    
    return 0
}

# Push vers registry
push_image() {
    log "📤 Push vers le registry..."
    
    # Vérifier si on est connecté à un registry
    if ! docker info > /dev/null 2>&1; then
        error "Docker daemon non accessible"
        return 1
    fi
    
    # Push des tags
    docker push "$IMAGE_NAME:$VERSION"
    docker push "$IMAGE_NAME:latest"
    
    log "✅ Push terminé"
}

# Fonction principale
main() {
    local target="production"
    local no_cache="false"
    local push="false"
    local clean="false"
    local scan="false"
    local dev_mode="false"
    
    # Parse des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -n|--no-cache)
                no_cache="true"
                shift
                ;;
            -p|--push)
                push="true"
                shift
                ;;
            -c|--clean)
                clean="true"
                shift
                ;;
            -s|--scan)
                scan="true"
                shift
                ;;
            -d|--dev)
                dev_mode="true"
                target="runtime"  # Target plus léger pour dev
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validation des targets
    local valid_targets=("base" "dependencies" "browsers" "runtime" "production")
    if [[ ! " ${valid_targets[*]} " =~ " $target " ]]; then
        error "Target invalide: $target"
        error "Targets valides: ${valid_targets[*]}"
        exit 1
    fi
    
    log "🚀 FLB Solutions - Build Docker"
    log "Version: $VERSION | Target: $target | Git: $GIT_COMMIT"
    
    # Exécution des étapes
    cd "$PROJECT_DIR"
    
    validate_environment
    
    if [[ "$clean" == "true" ]]; then
        clean_build
    fi
    
    if ! build_image "$target" "$no_cache" "$dev_mode"; then
        error "Échec de la construction"
        exit 1
    fi
    
    if ! test_image; then
        error "Échec des tests"
        exit 1
    fi
    
    if [[ "$scan" == "true" ]]; then
        if ! security_scan; then
            error "Échec du scan de sécurité"
            exit 1
        fi
    fi
    
    if [[ "$push" == "true" ]]; then
        if ! push_image; then
            error "Échec du push"
            exit 1
        fi
    fi
    
    log "🎉 Build terminé avec succès!"
    log "Image: $IMAGE_NAME:$VERSION"
    
    # Commandes utiles
    info ""
    info "Commandes utiles:"
    info "  docker run --rm -it $IMAGE_NAME:$VERSION bash"
    info "  docker run --rm -v \$(pwd)/test-results:/app/test-results $IMAGE_NAME:$VERSION"
    info "  docker-compose -f docker-compose.flb-optimized.yml up"
}

# Exécution
main "$@"