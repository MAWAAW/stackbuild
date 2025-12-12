#!/bin/bash

# Script de configuration des credentials

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════╗
║   Configuration des Credentials      ║
╚══════════════════════════════════════╝
EOF
echo -e "${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Vérifier si .env existe déjà
if [ -f "$ENV_FILE" ]; then
    print_warning "Un fichier .env existe déjà"
    echo ""
    cat "$ENV_FILE"
    echo ""
    read -p "Voulez-vous le reconfigurer? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Configuration annulée"
        exit 0
    fi
    mv "$ENV_FILE" "$ENV_FILE.backup.$(date +%s)"
    print_info "Ancien fichier sauvegardé"
fi

# Créer le fichier .env
echo "# Configuration Web Stack CLI" > "$ENV_FILE"
echo "# Généré automatiquement le $(date)" >> "$ENV_FILE"
echo "" >> "$ENV_FILE"

print_info "Configuration des credentials..."
echo ""

# ===== RENDER =====
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "1. Render API Key"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pour obtenir votre clé API Render :"
echo "  1. Allez sur : https://dashboard.render.com/account/api-keys"
echo "  2. Cliquez sur 'Create API Key'"
echo "  3. Donnez un nom (ex: web-stack-cli)"
echo "  4. Copiez la clé (format: rnd_xxxxx...)"
echo ""

read -p "Entrez votre RENDER_API_KEY (ou Entrée pour ignorer) : " render_key

if [ -n "$render_key" ]; then
    echo "export RENDER_API_KEY=$render_key" >> "$ENV_FILE"
    print_success "RENDER_API_KEY configuré"
else
    echo "# export RENDER_API_KEY=rnd_your_key_here" >> "$ENV_FILE"
    print_warning "RENDER_API_KEY ignoré (déploiement backend non disponible)"
fi

echo "" >> "$ENV_FILE"

# ===== NETLIFY =====
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "2. Netlify Auth Token"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pour obtenir votre token Netlify :"
echo "  Option A : Si vous avez Netlify CLI installé"
echo "    1. Exécutez : netlify login"
echo "    2. Le token sera détecté automatiquement"
echo ""
echo "  Option B : Manuellement"
echo "    1. Allez sur : https://app.netlify.com/user/applications/personal"
echo "    2. Créez un nouveau token"
echo "    3. Copiez-le"
echo ""

read -p "Entrez votre NETLIFY_AUTH_TOKEN (ou Entrée pour ignorer) : " netlify_input

if [ -n "$netlify_input" ]; then
    echo "export NETLIFY_AUTH_TOKEN=$netlify_input" >> "$ENV_FILE"
    print_success "NETLIFY_AUTH_TOKEN configuré"
else
    echo "# export NETLIFY_AUTH_TOKEN=your_token_here" >> "$ENV_FILE"
    print_warning "NETLIFY_AUTH_TOKEN ignoré (déploiement frontend non disponible)"
fi

echo "" >> "$ENV_FILE"

# ===== GITHUB =====
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "3. GitHub Token (optionnel)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    print_success "Vous êtes déjà authentifié avec GitHub CLI"
    github_token=$(gh auth token 2>/dev/null || echo "")
    
    if [ -n "$github_token" ]; then
        echo "export GITHUB_TOKEN=$github_token" >> "$ENV_FILE"
        print_success "GITHUB_TOKEN configuré automatiquement"
    fi
else
    echo "Pour configurer GitHub :"
    echo "  1. Exécutez : gh auth login"
    echo "  2. Ou créez un token sur : https://github.com/settings/tokens"
    echo ""
    read -p "Entrez votre GITHUB_TOKEN (ou Entrée pour ignorer) : " github_input
    
    if [ -n "$github_input" ]; then
        echo "export GITHUB_TOKEN=$github_input" >> "$ENV_FILE"
        print_success "GITHUB_TOKEN configuré"
    else
        echo "# export GITHUB_TOKEN=ghp_your_token_here" >> "$ENV_FILE"
        print_info "GITHUB_TOKEN ignoré"
    fi
fi

echo ""

# ===== RÉSUMÉ =====
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Configuration terminée !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Fichier créé : $ENV_FILE"
echo ""

# Vérifier ce qui est configuré
if grep -q "^export R
