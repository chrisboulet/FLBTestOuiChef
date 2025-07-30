#!/bin/bash

# Script de lancement des tests FLB Solutions
# Gère l'environnement virtuel et les dépendances automatiquement

set -e  # Arrêter en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_ENV_DIR="$SCRIPT_DIR/node_env"
NODE_VERSION="18"

print_status "🧪 FLB Solutions - Tests de Régression"
echo "════════════════════════════════════════════════"

# Vérifier si Node.js est installé
if ! command -v node &> /dev/null; then
    print_error "Node.js n'est pas installé. Veuillez l'installer d'abord."
    echo "Commande suggérée: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
fi

# Créer/activer l'environnement virtuel Node.js
if [ ! -d "$NODE_ENV_DIR" ]; then
    print_status "📦 Création de l'environnement virtuel Node.js..."
    mkdir -p "$NODE_ENV_DIR"
    
    # Créer un package.json local pour l'environnement
    cd "$NODE_ENV_DIR"
    npm init -y > /dev/null 2>&1
    cd "$SCRIPT_DIR"
    
    print_success "Environnement virtuel créé"
fi

# Fonction pour installer les dépendances
install_dependencies() {
    print_status "📥 Installation des dépendances..."
    
    # Installer les dépendances dans le répertoire principal
    cd "$SCRIPT_DIR"
    npm install
    
    # Installer les navigateurs Playwright
    print_status "🌐 Installation des navigateurs Playwright..."
    npx playwright install
    
    print_success "Dépendances installées"
}

# Vérifier si les dépendances sont installées
if [ ! -d "$SCRIPT_DIR/node_modules" ] || [ ! -f "$SCRIPT_DIR/node_modules/.bin/playwright" ]; then
    install_dependencies
else
    print_status "✅ Dépendances déjà installées"
fi

# Vérifier si le fichier .env existe
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_warning "Fichier .env non trouvé. Configuration des credentials..."
    node "$SCRIPT_DIR/setup-credentials.js"
fi

# Charger les variables d'environnement
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
    print_status "🔐 Variables d'environnement chargées"
fi

# Déterminer le type de test à exécuter
TEST_TYPE="${1:-smoke}"
TEST_OPTIONS="${2:-}"

case $TEST_TYPE in
    "setup")
        print_status "🔧 Configuration des credentials..."
        node "$SCRIPT_DIR/setup-credentials.js"
        ;;
    "smoke")
        print_status "🚨 Lancement des tests smoke (2-3 min)..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/smoke/ $TEST_OPTIONS
        ;;
    "auth")
        print_status "🔐 Lancement des tests authentifiés..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/smoke/flb-authenticated.spec.js $TEST_OPTIONS
        ;;
    "all")
        print_status "🎯 Lancement de tous les tests (5-10 min)..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/ $TEST_OPTIONS
        ;;
    "multi")
        print_status "🌐 Lancement multi-navigateurs (10-15 min)..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/ --project=chromium --project=firefox --project=webkit $TEST_OPTIONS
        ;;
    "parallel")
        print_status "⚡ Lancement tests parallèles..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/ --workers=4 $TEST_OPTIONS
        ;;
    "debug")
        print_status "🐛 Lancement en mode debug..."
        cd "$SCRIPT_DIR"
        npx playwright test tests/ --headed --debug $TEST_OPTIONS
        ;;
    "report")
        print_status "📊 Ouverture du rapport..."
        cd "$SCRIPT_DIR"
        npx playwright show-report
        ;;
    "clean")
        print_status "🧹 Nettoyage de l'environnement..."
        rm -rf "$NODE_ENV_DIR"
        rm -f "$SCRIPT_DIR/.env"
        print_success "Environnement nettoyé"
        ;;
    "help"|"-h"|"--help")
        echo ""
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "COMMANDS:"
        echo "  setup     Configuration des credentials"
        echo "  smoke     Tests smoke (défaut, 2-3 min)"
        echo "  auth      Tests authentifiés"
        echo "  all       Tous les tests (5-10 min)"
        echo "  multi     Multi-navigateurs (10-15 min)"
        echo "  parallel  Tests en parallèle"
        echo "  debug     Mode debug avec interface"
        echo "  report    Ouvrir le rapport HTML"
        echo "  clean     Nettoyer l'environnement"
        echo "  help      Afficher cette aide"
        echo ""
        echo "OPTIONS Playwright:"
        echo "  --headed          Avec interface graphique"
        echo "  --debug          Mode pas-à-pas"
        echo "  --project=NAME   Navigateur spécifique"
        echo "  --workers=N      Nombre de workers parallèles"
        echo ""
        echo "Exemples:"
        echo "  $0                    # Tests smoke"
        echo "  $0 auth --headed      # Tests auth avec interface"
        echo "  $0 multi              # Multi-navigateurs"
        echo "  $0 debug              # Mode debug"
        echo ""
        ;;
    *)
        print_error "Commande inconnue: $TEST_TYPE"
        echo "Utilisez '$0 help' pour voir les options disponibles"
        exit 1
        ;;
esac

# Afficher le rapport si les tests ont été exécutés
if [[ "$TEST_TYPE" =~ ^(smoke|auth|all|multi|parallel)$ ]] && [ $? -eq 0 ]; then
    echo ""
    print_success "Tests terminés !"
    echo "📊 Pour voir le rapport détaillé: $0 report"
fi