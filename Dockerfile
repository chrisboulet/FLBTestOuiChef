# ========================================
# FLB Solutions - Dockerfile Multi-Stage Optimisé
# Architecture: Tests Playwright E2E
# Sécurité: Non-root user, minimal attack surface
# Performance: Multi-stage build, layer caching
# ========================================

# ----------------------------------------
# Stage 1: Base Dependencies
# ----------------------------------------
FROM node:18-alpine AS dependencies

LABEL maintainer="FLB Solutions DevOps"
LABEL version="1.0.0"
LABEL description="Base dependencies pour tests Playwright FLB"

# Sécurité: Créer utilisateur non-root
RUN addgroup -g 1001 -S playwright && \
    adduser -S playwright -u 1001 -G playwright

# Variables d'environnement pour optimisation
ENV NODE_ENV=production
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Installation des dépendances système minimales
RUN apk add --no-cache \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copie et installation des dépendances Node.js
COPY package*.json ./
RUN npm ci --only=production --no-audit --no-fund && \
    npm cache clean --force

# ----------------------------------------
# Stage 2: Browser Installation
# ----------------------------------------
FROM mcr.microsoft.com/playwright:v1.54.1-jammy AS browsers

LABEL stage="browsers"

# Installation des navigateurs Playwright
RUN npx playwright install chromium firefox webkit && \
    npx playwright install-deps

# ----------------------------------------
# Stage 3: Test Environment
# ----------------------------------------
FROM node:18-alpine AS test-environment

# Variables d'environnement pour tests
ENV NODE_ENV=test
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
ENV DISPLAY=:99

# Installation des dépendances système pour tests
RUN apk add --no-cache \
    bash \
    jq \
    curl \
    git \
    ca-certificates \
    ttf-freefont \
    font-noto-emoji \
    && rm -rf /var/cache/apk/*

# Création utilisateur non-root
RUN addgroup -g 1001 -S playwright && \
    adduser -S playwright -u 1001 -G playwright

# Configuration des répertoires
WORKDIR /app
RUN mkdir -p /app/test-results /app/reports /app/screenshots && \
    chown -R playwright:playwright /app

# Copie des navigateurs depuis le stage browsers
COPY --from=browsers /opt/playwright-browsers /opt/playwright-browsers
COPY --from=browsers /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu

# Copie des dépendances depuis le stage dependencies
COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=dependencies /app/package*.json ./

# ----------------------------------------
# Stage 4: Production (Final)
# ----------------------------------------
FROM test-environment AS production

LABEL stage="production"
LABEL security.scan="trivy"

# Copie du code source et configuration
COPY --chown=playwright:playwright . .

# Scripts d'orchestration
COPY --chown=playwright:playwright docker/scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Configuration de santé
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Port pour monitoring (optionnel)
EXPOSE 3000

# Changement vers utilisateur non-root
USER playwright

# Point d'entrée avec gestion des signaux
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD ["npm", "run", "test"]

# ----------------------------------------
# Métadonnées et Documentation
# ----------------------------------------
LABEL org.opencontainers.image.title="FLB Solutions Test Suite"
LABEL org.opencontainers.image.description="Container optimisé pour tests E2E Playwright"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.created="2025-01-30"
LABEL org.opencontainers.image.source="https://github.com/flb-solutions/test-suite"
LABEL org.opencontainers.image.licenses="Proprietary"