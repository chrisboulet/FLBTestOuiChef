#!/bin/bash
# ========================================
# FLB Solutions - Setup Secrets Script
# Configuration sécurisée des secrets Docker
# ========================================

set -euo pipefail

# Configuration des couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SECRETS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV=${ENV:-dev}

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] SECRETS:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARN:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Validation de l'environnement
validate_environment() {
    log "🔍 Validation de l'environnement de secrets..."
    
    # Vérification des permissions
    if [[ ! -w "$SECRETS_DIR" ]]; then
        error "Permissions insuffisantes sur $SECRETS_DIR"
        exit 1
    fi
    
    # Vérification des outils requis
    for tool in openssl jq; do
        if ! command -v "$tool" &> /dev/null; then
            error "Outil requis manquant: $tool"
            exit 1
        fi
    done
    
    info "✅ Environnement validé"
}

# Génération d'une clé de chiffrement forte
generate_encryption_key() {
    openssl rand -base64 32
}

# Génération d'un mot de passe sécurisé
generate_password() {
    local length=${1:-24}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Chiffrement d'une valeur
encrypt_value() {
    local value="$1"
    local key="$2"
    echo -n "$value" | openssl enc -aes-256-cbc -pbkdf2 -base64 -pass pass:"$key"
}

# Configuration des secrets par environnement
setup_credentials() {
    local env="$1"
    local credentials_file="$SECRETS_DIR/credentials.json"
    local template_file="$SECRETS_DIR/credentials.example.json"
    
    log "🔐 Configuration des credentials pour l'environnement: $env"
    
    # Vérification du template
    if [[ ! -f "$template_file" ]]; then
        error "Template manquant: $template_file"
        exit 1
    fi
    
    # Génération de la clé de chiffrement principale
    local master_key
    master_key=$(generate_encryption_key)
    
    # Configuration spécifique par environnement
    case "$env" in
        "dev")
            setup_dev_credentials "$credentials_file" "$template_file" "$master_key"
            ;;
        "test")
            setup_test_credentials "$credentials_file" "$template_file" "$master_key"
            ;;
        "staging")
            setup_staging_credentials "$credentials_file" "$template_file" "$master_key"
            ;;
        "prod")
            setup_prod_credentials "$credentials_file" "$template_file" "$master_key"
            ;;
        *)
            error "Environnement non supporté: $env"
            exit 1
            ;;
    esac
    
    # Sécurisation du fichier
    chmod 600 "$credentials_file"
    
    # Sauvegarde de la clé de chiffrement
    echo "$master_key" > "$SECRETS_DIR/.encryption_key_$env"
    chmod 600 "$SECRETS_DIR/.encryption_key_$env"
    
    log "✅ Credentials configurés pour $env"
}

# Configuration développement
setup_dev_credentials() {
    local credentials_file="$1"
    local template_file="$2"
    local master_key="$3"
    
    info "Génération des credentials de développement..."
    
    # Copie du template et modification
    cp "$template_file" "$credentials_file"
    
    # Génération de mots de passe de test
    local admin_password="dev_admin_$(generate_password 12)"
    local customer_password="dev_customer_$(generate_password 12)"
    local api_key="dev_$(generate_password 32)"
    
    # Mise à jour du fichier JSON
    jq --arg admin_pwd "$admin_password" \
       --arg customer_pwd "$customer_password" \
       --arg api_key "$api_key" \
       --arg jwt_secret "$(generate_password 32)" \
       '.flb_solutions.accounts.admin.password = $admin_pwd |
        .flb_solutions.accounts.customer.password = $customer_pwd |
        .flb_solutions.api.key = $api_key |
        .environment.jwt_secret = $jwt_secret' \
       "$credentials_file" > "$credentials_file.tmp"
    
    mv "$credentials_file.tmp" "$credentials_file"
    
    info "Credentials de développement générés"
}

# Configuration test
setup_test_credentials() {
    local credentials_file="$1"
    local template_file="$2"
    local master_key="$3"
    
    info "Génération des credentials de test..."
    
    cp "$template_file" "$credentials_file"
    
    # Mots de passe de test répétables
    local admin_password="test_admin_secure123"
    local customer_password="test_customer_secure123"
    local api_key="test_$(generate_password 32)"
    
    jq --arg admin_pwd "$admin_password" \
       --arg customer_pwd "$customer_password" \
       --arg api_key "$api_key" \
       --arg jwt_secret "$(generate_password 32)" \
       '.flb_solutions.accounts.admin.password = $admin_pwd |
        .flb_solutions.accounts.customer.password = $customer_pwd |
        .flb_solutions.api.key = $api_key |
        .environment.jwt_secret = $jwt_secret' \
       "$credentials_file" > "$credentials_file.tmp"
    
    mv "$credentials_file.tmp" "$credentials_file"
    
    info "Credentials de test générés"
}

# Configuration staging
setup_staging_credentials() {
    local credentials_file="$1"
    local template_file="$2"
    local master_key="$3"
    
    info "Génération des credentials de staging..."
    
    cp "$template_file" "$credentials_file"
    
    # Passwords plus sécurisés pour staging
    local admin_password="staging_$(generate_password 24)"
    local customer_password="staging_$(generate_password 24)"
    local api_key="staging_$(generate_password 40)"
    
    # Chiffrement des valeurs sensibles
    local encrypted_admin_pwd
    local encrypted_customer_pwd
    local encrypted_api_key
    
    encrypted_admin_pwd=$(encrypt_value "$admin_password" "$master_key")
    encrypted_customer_pwd=$(encrypt_value "$customer_password" "$master_key")
    encrypted_api_key=$(encrypt_value "$api_key" "$master_key")
    
    jq --arg admin_pwd "$encrypted_admin_pwd" \
       --arg customer_pwd "$encrypted_customer_pwd" \
       --arg api_key "$encrypted_api_key" \
       --arg jwt_secret "$(generate_password 40)" \
       --arg encryption_key "$master_key" \
       '.flb_solutions.accounts.admin.password = $admin_pwd |
        .flb_solutions.accounts.customer.password = $customer_pwd |
        .flb_solutions.api.key = $api_key |
        .environment.jwt_secret = $jwt_secret |
        .environment.encryption_key = $encryption_key' \
       "$credentials_file" > "$credentials_file.tmp"
    
    mv "$credentials_file.tmp" "$credentials_file"
    
    info "Credentials de staging générés avec chiffrement"
}

# Configuration production
setup_prod_credentials() {
    local credentials_file="$1"
    local template_file="$2"
    local master_key="$3"
    
    warn "⚠️  Configuration PRODUCTION - Sécurité maximale requise"
    
    # Vérification interactive pour production
    read -p "Confirmer la génération des credentials de PRODUCTION? (oui/non): " -r
    if [[ ! $REPLY =~ ^(oui|OUI|yes|YES)$ ]]; then
        error "Configuration production annulée"
        exit 1
    fi
    
    cp "$template_file" "$credentials_file"
    
    # Mots de passe ultra-sécurisés pour production
    local admin_password="prod_$(generate_password 32)"
    local customer_password="prod_$(generate_password 32)"
    local api_key="prod_$(generate_password 48)"
    
    # Chiffrement renforcé
    local encrypted_admin_pwd
    local encrypted_customer_pwd
    local encrypted_api_key
    
    encrypted_admin_pwd=$(encrypt_value "$admin_password" "$master_key")
    encrypted_customer_pwd=$(encrypt_value "$customer_password" "$master_key")
    encrypted_api_key=$(encrypt_value "$api_key" "$master_key")
    
    jq --arg admin_pwd "$encrypted_admin_pwd" \
       --arg customer_pwd "$encrypted_customer_pwd" \
       --arg api_key "$encrypted_api_key" \
       --arg jwt_secret "$(generate_password 48)" \
       --arg encryption_key "$master_key" \
       '.flb_solutions.accounts.admin.password = $admin_pwd |
        .flb_solutions.accounts.customer.password = $customer_pwd |
        .flb_solutions.api.key = $api_key |
        .environment.jwt_secret = $jwt_secret |
        .environment.encryption_key = $encryption_key' \
       "$credentials_file" > "$credentials_file.tmp"
    
    mv "$credentials_file.tmp" "$credentials_file"
    
    warn "🔒 Credentials de production générés - SAUVEGARDER LA CLÉ DE CHIFFREMENT!"
    warn "Clé sauvegardée dans: $SECRETS_DIR/.encryption_key_prod"
}

# Configuration des API keys
setup_api_keys() {
    local env="$1"
    local api_keys_file="$SECRETS_DIR/api-keys.json"
    
    log "🔑 Configuration des API keys pour: $env"
    
    # Structure de base des API keys
    cat > "$api_keys_file" << EOF
{
    "flb_solutions": {
        "internal_api": "$(generate_password 32)",
        "webhook_secret": "$(generate_password 24)"
    },
    "monitoring": {
        "prometheus": "$(generate_password 16)",
        "grafana": "$(generate_password 16)"
    },
    "external": {
        "stripe_test": "sk_test_$(generate_password 32)",
        "paypal_sandbox": "$(generate_password 32)",
        "sendgrid": "SG.$(generate_password 32)"
    },
    "environment": "$env",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    chmod 600 "$api_keys_file"
    
    info "✅ API keys configurées"
}

# Génération des certificats SSL de test
setup_ssl_certificates() {
    local env="$1"
    local ssl_dir="$SECRETS_DIR/ssl"
    
    if [[ "$env" == "prod" ]]; then
        warn "Production SSL - Utiliser des certificats Let's Encrypt ou CA valide"
        return 0
    fi
    
    log "🔐 Génération des certificats SSL de test pour: $env"
    
    mkdir -p "$ssl_dir"
    
    # Génération d'un certificat auto-signé pour les tests
    openssl req -x509 -newkey rsa:4096 -keyout "$ssl_dir/key.pem" -out "$ssl_dir/cert.pem" \
        -days 365 -nodes -subj "/C=CA/ST=QC/L=Montreal/O=FLB Solutions/CN=flb-tests-$env"
    
    chmod 600 "$ssl_dir/key.pem"
    chmod 644 "$ssl_dir/cert.pem"
    
    info "✅ Certificats SSL générés"
}

# Nettoyage sécurisé
cleanup_sensitive_files() {
    log "🧹 Nettoyage des fichiers temporaires..."
    
    # Nettoyage sécurisé des fichiers temporaires
    find "$SECRETS_DIR" -name "*.tmp" -type f -exec shred -vfz -n 3 {} \; 2>/dev/null || true
    find "$SECRETS_DIR" -name "*.tmp" -type f -delete 2>/dev/null || true
    
    info "✅ Nettoyage terminé"
}

# Affichage de l'aide
show_help() {
    cat << EOF
🔐 FLB Solutions - Setup Secrets

Usage: $0 [OPTIONS] ENVIRONMENT

Environnements supportés:
    dev         Développement (passwords simples)
    test        Test (passwords répétables)  
    staging     Staging (chiffrement activé)
    prod        Production (sécurité maximale)

Options:
    --api-keys-only     Générer uniquement les API keys
    --ssl-only          Générer uniquement les certificats SSL
    --cleanup           Nettoyage des fichiers temporaires uniquement
    -h, --help          Afficher cette aide

Variables d'environnement:
    ENV                 Environnement cible (dev|test|staging|prod)

Exemples:
    $0 dev              # Configuration complète développement
    $0 test             # Configuration complète test
    $0 staging          # Configuration staging avec chiffrement
    $0 prod             # Configuration production sécurisée
    $0 --api-keys-only dev  # API keys uniquement

Sécurité:
    - Développement: Passwords en clair, régénérés à chaque setup
    - Test: Passwords répétables pour les tests automatisés
    - Staging: Chiffrement AES-256 avec clé maître
    - Production: Chiffrement renforcé + validation interactive
EOF
}

# Parsing des arguments
parse_arguments() {
    local api_keys_only=false
    local ssl_only=false
    local cleanup_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-keys-only)
                api_keys_only=true
                shift
                ;;
            --ssl-only)
                ssl_only=true
                shift
                ;;
            --cleanup)
                cleanup_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            dev|test|staging|prod)
                ENV="$1"
                shift
                ;;
            *)
                error "Argument inconnu: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validation de l'environnement
    if [[ -z "$ENV" ]] && [[ "$cleanup_only" == "false" ]]; then
        error "Environnement requis (dev|test|staging|prod)"
        show_help
        exit 1
    fi
    
    # Exécution basée sur les options
    if [[ "$cleanup_only" == "true" ]]; then
        cleanup_sensitive_files
        exit 0
    elif [[ "$api_keys_only" == "true" ]]; then
        setup_api_keys "$ENV"
        exit 0
    elif [[ "$ssl_only" == "true" ]]; then
        setup_ssl_certificates "$ENV"
        exit 0
    fi
}

# Point d'entrée principal
main() {
    log "🔐 FLB Solutions - Configuration des Secrets"
    log "Environnement: $ENV"
    
    validate_environment
    setup_credentials "$ENV"
    setup_api_keys "$ENV"
    setup_ssl_certificates "$ENV"
    cleanup_sensitive_files
    
    log "✅ Configuration des secrets terminée pour: $ENV"
    
    # Affichage des informations importantes
    info "📋 Fichiers générés:"
    info "  - credentials.json (comptes et API)"
    info "  - api-keys.json (clés externes)"
    info "  - ssl/cert.pem et ssl/key.pem (certificats)"
    info "  - .encryption_key_$ENV (clé de chiffrement)"
    
    warn "⚠️  IMPORTANT:"
    warn "  - Sauvegarder la clé de chiffrement en lieu sûr"
    warn "  - Ne jamais commiter les fichiers secrets"
    warn "  - Permissions 600 appliquées automatiquement"
}

# Exécution
parse_arguments "$@"
main