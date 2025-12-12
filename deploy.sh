#!/bin/bash

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Messages helpers
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Banner
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╦ ╦┌─┐┌┐   ╔═╗┌┬┐┌─┐┌─┐┬┌─  ╔═╗╦  ╦
║║║├┤ ├┴┐  ╚═╗ │ ├─┤│  ├┴┐  ║  ║  ║
╚╩╝└─┘└─┘  ╚═╝ ┴ ┴ ┴└─┘┴ ┴  ╚═╝╩═╝╩
    Full-Stack Generator & Deployer
EOF
    echo -e "${NC}"
}

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$SCRIPT_DIR/cli"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
GENERATED_DIR="$SCRIPT_DIR/generated"

# Charger les variables d'environnement depuis .env si présent
if [ -f "$SCRIPT_DIR/.env" ]; then
    print_info "Chargement des variables depuis .env..."
    source "$SCRIPT_DIR/.env"
elif [ -f ".env" ]; then
    print_info "Chargement des variables depuis .env..."
    source .env
fi

# Afficher l'aide
show_help() {
    cat << EOF
Usage: ./deploy.sh [COMMAND] [OPTIONS]

Commands:
    init [PROJECT_NAME]         Initialiser un nouveau projet
    dev                         Lancer l'environnement de développement local
    deploy                      Déployer le projet sur le cloud
    config                      Configurer le projet
    help                        Afficher cette aide

Options pour 'init':
    --backend=TYPE             Backend: spring|node|fastapi (défaut: spring)
    --frontend=TYPE            Frontend: angular|react|vue (défaut: angular)
    --db=TYPE                  Database: postgres|mysql|mongodb (défaut: postgres)
    --auth                     Inclure l'authentification JWT (défaut: true)
    --no-auth                  Désactiver l'authentification
    --skip-deploy              Ne pas déployer après génération

Options pour 'deploy':
    --backend-only             Déployer uniquement le backend
    --frontend-only            Déployer uniquement le frontend
    --all                      Déployer tous les composants (défaut)

Exemples:
    ./deploy.sh init my-app
    ./deploy.sh init my-app --backend=node --frontend=react --db=mongodb
    ./deploy.sh dev
    ./deploy.sh deploy --all

EOF
}

# Vérifier les prérequis
check_prerequisites() {
    print_info "Vérification des prérequis..."
    
    local missing=0
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose n'est pas installé (optionnel)"
    fi
    
    if ! command -v git &> /dev/null; then
        print_error "Git n'est pas installé"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        print_error "Veuillez installer les dépendances manquantes"
        exit 1
    fi
    
    print_success "Tous les prérequis sont satisfaits"
}

# Initialiser un nouveau projet
init_project() {
    local project_name=$1
    shift
    
    # Valeurs par défaut
    local backend="spring"
    local frontend="angular"
    local db="postgres"
    local auth=true
    local skip_deploy=false
    
    # Parser les options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend=*)
                backend="${1#*=}"
                shift
                ;;
            --frontend=*)
                frontend="${1#*=}"
                shift
                ;;
            --db=*)
                db="${1#*=}"
                shift
                ;;
            --no-auth)
                auth=false
                shift
                ;;
            --skip-deploy)
                skip_deploy=true
                shift
                ;;
            *)
                print_error "Option inconnue: $1"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$project_name" ]; then
        print_error "Nom de projet requis"
        echo "Usage: ./deploy.sh init [PROJECT_NAME]"
        exit 1
    fi
    
    print_info "Création du projet: $project_name"
    print_info "  Backend: $backend"
    print_info "  Frontend: $frontend"
    print_info "  Database: $db"
    print_info "  Auth: $auth"
    echo ""
    
    # Créer le répertoire du projet
    local project_dir="$GENERATED_DIR/$project_name"
    mkdir -p "$project_dir"
    
    # Générer le backend
    print_info "Génération du backend ($backend)..."
    source "$CLI_DIR/generators/backend/${backend}-generator.sh"
    generate_backend "$project_dir" "$project_name" "$auth"
    
    # Générer le frontend
    print_info "Génération du frontend ($frontend)..."
    source "$CLI_DIR/generators/frontend/${frontend}-generator.sh"
    generate_frontend "$project_dir" "$project_name" "$backend"
    
    # Générer la configuration database
    print_info "Configuration de la base de données ($db)..."
    source "$CLI_DIR/generators/database/${db}-generator.sh"
    generate_database_config "$project_dir" "$backend"
    
    # Générer docker-compose
    print_info "Génération de docker-compose.yml..."
    source "$CLI_DIR/utils/docker-utils.sh"
    generate_docker_compose "$project_dir" "$backend" "$frontend" "$db"
    
    # Générer GitHub Actions
    print_info "Génération des workflows CI/CD..."
    generate_github_actions "$project_dir" "$backend" "$frontend"
    
    # Initialiser Git et créer le repo GitHub
    source "$CLI_DIR/utils/git-utils.sh"
    
    initialize_git_repo "$project_dir" "$project_name"
    
    print_success "Projet '$project_name' créé avec succès!"
    echo ""
    
    # Demander si on crée le repo GitHub
    read -p "Créer automatiquement le dépôt GitHub? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Vérifier/installer gh CLI si nécessaire
        if ! command -v gh &> /dev/null; then
            print_info "Installation de GitHub CLI..."
            install_gh_cli
        fi
        
        # Créer le repo GitHub
        if create_github_repo "$project_dir" "$project_name" true; then
            print_success "Dépôt GitHub créé et code poussé!"
            
            # Demander si on configure les secrets pour CI/CD
            read -p "Configurer les secrets GitHub pour le déploiement automatique? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                setup_github_secrets "$project_dir"
            fi
        fi
    else
        print_info "Pour créer le dépôt GitHub plus tard:"
        echo "  cd generated/$project_name"
        echo "  gh repo create $project_name --public --source=. --remote=origin --push"
    fi
    
    echo ""
    print_info "Pour lancer en local:"
    echo "  cd generated/$project_name"
    echo "  docker-compose up"
    echo ""
    
    if [ "$skip_deploy" = false ]; then
        read -p "Voulez-vous déployer maintenant sur Render et Netlify? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$project_dir"
            deploy_project "all"
            cd - > /dev/null
        else
            print_info "Pour déployer plus tard:"
            echo "  cd generated/$project_name"
            echo "  ../../deploy.sh deploy"
        fi
    fi
}

# Lancer l'environnement de dev
dev_mode() {
    print_info "Lancement de l'environnement de développement..."
    
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Fichier docker-compose.yml introuvable"
        print_info "Êtes-vous dans le répertoire du projet?"
        exit 1
    fi
    
    docker-compose up --build
}

# Déployer le projet
deploy_project() {
    local target=${1:-all}
    
    # Enlever le -- si présent
    target=${target#--}
    
    print_info "Déploiement du projet..."
    
    source "$CLI_DIR/deployers/render-deploy.sh"
    source "$CLI_DIR/deployers/netlify-deploy.sh"
    
    case $target in
        backend-only|backend)
            deploy_to_render
            ;;
        frontend-only|frontend)
            deploy_to_netlify
            ;;
        all)
            deploy_to_render
            deploy_to_netlify
            ;;
        *)
            print_error "Cible de déploiement invalide: $target"
            echo "Options valides: --all, --backend-only, --frontend-only"
            exit 1
            ;;
    esac
    
    print_success "Déploiement terminé!"
}

# Configuration du projet
configure_project() {
    print_info "Configuration du projet..."
    source "$CLI_DIR/commands/config.sh"
    run_configuration
}

# Fonction principale
main() {
    print_banner
    check_prerequisites
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command=$1
    shift
    
    case $command in
        init)
            init_project "$@"
            ;;
        dev)
            dev_mode
            ;;
        deploy)
            deploy_project "$@"
            ;;
        config)
            configure_project
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

# Lancer le script
main "$@"