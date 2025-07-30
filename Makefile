# ========================================
# FLB Solutions - Makefile Docker
# Commandes simplifiées pour gestion Docker
# ========================================

# Configuration
IMAGE_NAME := flb-solutions/playwright-tests
VERSION := 2.0.0
DOCKERFILE := Dockerfile.optimized
COMPOSE_FILE := docker-compose.flb-optimized.yml

# Couleurs pour output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

.PHONY: help build build-dev build-clean test validate run run-dev up down logs clean scan push

# Cible par défaut
.DEFAULT_GOAL := help

## Affiche l'aide
help:
	@echo "$(YELLOW)🐳 FLB Solutions - Docker Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)📦 Build Commands:$(NC)"
	@echo "  build       - Construction standard de l'image"
	@echo "  build-dev   - Construction pour développement"
	@echo "  build-clean - Construction sans cache"
	@echo "  build-scan  - Construction avec scan sécurité"
	@echo ""
	@echo "$(GREEN)🧪 Test Commands:$(NC)"
	@echo "  test        - Tests rapides de l'image"
	@echo "  validate    - Validation complète du container"
	@echo ""
	@echo "$(GREEN)🚀 Run Commands:$(NC)"
	@echo "  run         - Exécution simple des tests"
	@echo "  run-dev     - Exécution en mode développement"
	@echo "  run-shell   - Shell interactif dans le container"
	@echo ""
	@echo "$(GREEN)🐙 Compose Commands:$(NC)"  
	@echo "  up          - Démarrage stack complète"
	@echo "  up-tests    - Démarrage tests uniquement"
	@echo "  down        - Arrêt de la stack"
	@echo "  logs        - Affichage des logs"
	@echo "  logs-f      - Suivi des logs en temps réel"
	@echo ""
	@echo "$(GREEN)🛠️  Maintenance Commands:$(NC)"
	@echo "  clean       - Nettoyage images et containers"
	@echo "  scan        - Scan sécurité de l'image"
	@echo "  push        - Push vers registry"
	@echo "  status      - Status des containers"
	@echo ""
	@echo "$(YELLOW)Exemples:$(NC)"
	@echo "  make build-dev      # Build développement"
	@echo "  make run ENV=staging # Tests staging"
	@echo "  make up-tests       # Stack tests only"

## Construction standard de l'image
build:
	@echo "$(GREEN)🏗️  Construction de l'image $(IMAGE_NAME):$(VERSION)$(NC)"
	./docker/scripts/build.sh

## Construction pour développement  
build-dev:
	@echo "$(GREEN)🛠️  Construction développement$(NC)"
	./docker/scripts/build.sh --dev

## Construction sans cache
build-clean:
	@echo "$(GREEN)🧹 Construction propre (sans cache)$(NC)"
	./docker/scripts/build.sh --clean --no-cache

## Construction avec scan sécurité
build-scan:
	@echo "$(GREEN)🛡️  Construction avec scan sécurité$(NC)"
	./docker/scripts/build.sh --scan

## Tests rapides de l'image
test:
	@echo "$(GREEN)🧪 Tests rapides de l'image$(NC)"
	docker run --rm $(IMAGE_NAME):$(VERSION) node --version
	docker run --rm $(IMAGE_NAME):$(VERSION) npx playwright --version
	@echo "$(GREEN)✅ Tests de base réussis$(NC)"

## Validation complète du container
validate:
	@echo "$(GREEN)🔍 Validation complète du container$(NC)"
	./docker/scripts/validate.sh

## Exécution simple des tests
run:
	@echo "$(GREEN)🚀 Exécution des tests Playwright$(NC)"
	docker run --rm \
		-v $$(pwd)/test-results:/app/test-results \
		-v $$(pwd)/reports:/app/reports \
		-v $$(pwd)/screenshots:/app/screenshots \
		-e ENV_TYPE=$(ENV_TYPE) \
		$(IMAGE_NAME):$(VERSION)

## Exécution en mode développement
run-dev:
	@echo "$(GREEN)🛠️  Exécution mode développement$(NC)"
	docker run --rm -it \
		-v $$(pwd)/test-results:/app/test-results \
		-v $$(pwd)/reports:/app/reports \
		-v $$(pwd)/screenshots:/app/screenshots \
		-v $$(pwd)/tests:/app/tests \
		-e ENV_TYPE=dev \
		-e DEBUG=true \
		-e HEADLESS=false \
		-p 3000:3000 \
		-p 9323:9323 \
		$(IMAGE_NAME):$(VERSION)

## Shell interactif dans le container
run-shell:
	@echo "$(GREEN)🐚 Shell interactif$(NC)"
	docker run --rm -it \
		-v $$(pwd):/workspace \
		$(IMAGE_NAME):$(VERSION) bash

## Démarrage stack complète
up:
	@echo "$(GREEN)🐙 Démarrage stack complète$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)📊 Services disponibles:$(NC)"
	@echo "  - Tests FLB: http://localhost:3000"
	@echo "  - Rapports: http://localhost:9323"  
	@echo "  - Prometheus: http://localhost:9090"
	@echo "  - Grafana: http://localhost:3001"

## Démarrage tests uniquement
up-tests:
	@echo "$(GREEN)🧪 Démarrage tests uniquement$(NC)"
	docker-compose -f $(COMPOSE_FILE) up flb-tests redis-cache

## Arrêt de la stack
down:
	@echo "$(GREEN)🛑 Arrêt de la stack$(NC)"
	docker-compose -f $(COMPOSE_FILE) down

## Affichage des logs
logs:
	@echo "$(GREEN)📋 Logs des services$(NC)"
	docker-compose -f $(COMPOSE_FILE) logs

## Suivi des logs en temps réel
logs-f:
	@echo "$(GREEN)📡 Suivi des logs$(NC)"
	docker-compose -f $(COMPOSE_FILE) logs -f

## Status des containers
status:
	@echo "$(GREEN)📊 Status des containers$(NC)"
	@docker ps --filter "label=com.flb.service" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@docker-compose -f $(COMPOSE_FILE) ps

## Nettoyage images et containers
clean:
	@echo "$(GREEN)🧹 Nettoyage Docker$(NC)"
	docker-compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f
	docker volume prune -f
	@echo "$(GREEN)✅ Nettoyage terminé$(NC)"

## Scan sécurité de l'image
scan:
	@echo "$(GREEN)🛡️  Scan sécurité$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE_NAME):$(VERSION); \
	else \
		echo "$(RED)❌ Trivy non installé$(NC)"; \
		echo "Installation: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"; \
	fi

## Push vers registry
push:
	@echo "$(GREEN)📤 Push vers registry$(NC)"
	./docker/scripts/build.sh --push

## Test de connectivité vers FLB
test-connectivity:
	@echo "$(GREEN)🌐 Test connectivité FLB Solutions$(NC)"
	@if curl -s --connect-timeout 5 https://www.flbsolutions.com > /dev/null; then \
		echo "$(GREEN)✅ FLB Solutions accessible$(NC)"; \
	else \
		echo "$(RED)❌ FLB Solutions non accessible$(NC)"; \
	fi

## Informations système
info:
	@echo "$(GREEN)ℹ️  Informations système$(NC)"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$(docker-compose --version)"
	@echo "Image: $(IMAGE_NAME):$(VERSION)"
	@echo "Dockerfile: $(DOCKERFILE)"
	@echo "Compose file: $(COMPOSE_FILE)"
	@echo ""
	@echo "$(GREEN)📦 Images FLB:$(NC)"
	@docker images $(IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" || true

## Démonstration complète
demo: build-dev test validate up-tests
	@echo "$(GREEN)🎉 Démonstration terminée!$(NC)"
	@echo "$(YELLOW)Services démarrés - utilisez 'make logs-f' pour suivre$(NC)"

# Variables d'environnement par défaut
ENV_TYPE ?= test

# Targets qui ne créent pas de fichiers
.PHONY: $(MAKECMDGOALS)