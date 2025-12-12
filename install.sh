#!/bin/bash

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╦╔╗╔╔═╗╔╦╗╔═╗╦  ╦  ╔═╗╦═╗
║║║║╚═╗ ║ ╠═╣║  ║  ║╣ ╠╦╝
╩╝╚╝╚═╝ ╩ ╩ ╩╩═╝╩═╝╚═╝╩╚═
  Web Stack CLI Setup
EOF
    echo -e "${NC}"
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_docker_linux() {
    print_info "Installation de Docker sur Linux..."
    
    # Mettre à jour les packages
    sudo apt-get update
    
    # Installer les prérequis
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Ajouter la clé GPG Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Ajouter le repo Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Installer Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Ajouter l'utilisateur au groupe docker
    sudo usermod -aG docker $USER
    
    print_success "Docker installé avec succès"
    print_warning "Déconnectez-vous et reconnectez-vous pour utiliser Docker sans sudo"
}

install_docker_macos() {
    print_info "Installation de Docker sur macOS..."
    
    if check_command brew; then
        brew install --cask docker
        print_success "Docker installé avec succès"
        print_info "Lancez Docker Desktop depuis Applications"
    else
        print_error "Homebrew n'est pas installé"
        print_info "Installez Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        print_info "Ou téléchargez Docker Desktop: https://www.docker.com/products/docker-desktop"
    fi
}

install_docker_windows() {
    print_info "Installation de Docker sur Windows..."
    print_warning "Docker Desktop doit être installé manuellement"
    print_info "Téléchargez depuis: https://www.docker.com/products/docker-desktop"
    print_info "Ou utilisez WSL2 avec Docker"
}

install_git() {
    local os=$(detect_os)
    
    print_info "Installation de Git..."
    
    case $os in
        linux)
            sudo apt-get update
            sudo apt-get install -y git
            ;;
        macos)
            if check_command brew; then
                brew install git
            else
                print_error "Homebrew requis pour installer Git"
                return 1
            fi
            ;;
        windows)
            print_warning "Installez Git depuis: https://git-scm.com/download/win"
            return 1
            ;;
    esac
    
    print_success "Git installé"
}

install_node() {
    local os=$(detect_os)
    
    print_info "Installation de Node.js..."
    
    case $os in
        linux)
            # Installer via NodeSource
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        macos)
            if check_command brew; then
                brew install node@20
            else
                print_error "Homebrew requis"
                return 1
            fi
            ;;
        windows)
            print_warning "Installez Node.js depuis: https://nodejs.org"
            return 1
            ;;
    esac
    
    print_success "Node.js $(node --version) installé"
}

install_java() {
    local os=$(detect_os)
    
    print_info "Installation de Java 17..."
    
    case $os in
        linux)
            sudo apt-get update
            sudo apt-get install -y openjdk-17-jdk
            ;;
        macos)
            if check_command brew; then
                brew install openjdk@17
            else
                print_error "Homebrew requis"
                return 1
            fi
            ;;
        windows)
            print_warning "Installez Java depuis: https://adoptium.net"
            return 1
            ;;
    esac
    
    print_success "Java installé"
}

install_python() {
    local os=$(detect_os)
    
    print_info "Installation de Python 3.11..."
    
    case $os in
        linux)
            sudo apt-get update
            sudo apt-get install -y python3.11 python3.11-venv python3-pip
            ;;
        macos)
            if check_command brew; then
                brew install python@3.11
            else
                print_error "Homebrew requis"
                return 1
            fi
            ;;
        windows)
            print_warning "Installez Python depuis: https://www.python.org"
            return 1
            ;;
    esac
    
    print_success "Python $(python --version) installé"
}

install_netlify_cli() {
    print_info "Installation de Netlify CLI..."
    
    if check_command npm; then
        npm install -g netlify-cli
        print_success "Netlify CLI installé"
    else
        print_error "Node.js/npm requis pour Netlify CLI"
        return 1
    fi
}

install_github_cli() {
    print_info "Installation de GitHub CLI..."
    
    case $os in
        linux)
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update
            sudo apt install gh -y
            ;;
        macos)
            if check_command brew; then
                brew install gh
            else
                print_error "Homebrew requis"
                return 1
            fi
            ;;
        windows)
            print_warning "Installez GitHub CLI depuis: https://cli.github.com"
            return 1
            ;;
    esac
    
    print_success "GitHub CLI installé"
}

main() {
    print_banner
    
    local os=$(detect_os)
    print_info "Système d'exploitation détecté: $os"
    echo ""
    
    # Vérifier les dépendances
    print_info "Vérification des dépendances..."
    echo ""
    
    local missing=()
    
    # Docker
    if check_command docker; then
        print_success "Docker: installé ($(docker --version))"
    else
        print_warning "Docker: non installé"
        missing+=("docker")
    fi
    
    # Git
    if check_command git; then
        print_success "Git: installé ($(git --version))"
    else
        print_warning "Git: non installé"
        missing+=("git")
    fi
    
    # Node.js
    if check_command node; then
        print_success "Node.js: installé ($(node --version))"
    else
        print_warning "Node.js: non installé"
        missing+=("node")
    fi
    
    # GitHub CLI
    if check_command gh; then
        print_success "GitHub CLI: installé ($(gh --version | head -1))"
    else
        print_info "GitHub CLI: non installé (recommandé pour automatisation)"
    fi
    
    # Netlify CLI
    if check_command netlify; then
        print_success "Netlify CLI: installé"
    else
        print_info "Netlify CLI: non installé (recommandé pour déploiement)"
    fi
    
    # Java (optionnel)
    if check_command java; then
        print_success "Java: installé ($(java --version 2>&1 | head -n 1))"
    else
        print_info "Java: non installé (optionnel pour Spring Boot)"
    fi
    
    # Python (optionnel)
    if check_command python; then
        print_success "Python: installé ($(python --version))"
    else
        print_info "Python: non installé (optionnel pour FastAPI)"
    fi
    
    echo ""
    
    # Si des dépendances manquent
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "Dépendances manquantes: ${missing[*]}"
        echo ""
        
        read -p "Voulez-vous installer les dépendances manquantes? (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for dep in "${missing[@]}"; do
                case $dep in
                    docker)
                        case $os in
                            linux) install_docker_linux ;;
                            macos) install_docker_macos ;;
                            windows) install_docker_windows ;;
                        esac
                        ;;
                    git)
                        install_git
                        ;;
                    node)
                        install_node
                        ;;
                esac
            done
        fi
    else
        print_success "Toutes les dépendances requises sont installées!"
    fi
    
    echo ""
    print_info "Installation des outils optionnels..."
    echo ""
    
    # GitHub CLI
    if ! check_command gh; then
        read -p "Installer GitHub CLI (recommandé)? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_github_cli
        fi
    fi
    
    # Netlify CLI
    if ! check_command netlify; then
        read -p "Installer Netlify CLI (recommandé)? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_netlify_cli
        fi
    fi
    
    echo ""
    print_success "Installation terminée!"
    echo ""
    
    print_info "Prochaines étapes:"
    echo "  1. Rendez deploy.sh exécutable: chmod +x deploy.sh"
    echo "  2. Créez votre premier projet: ./deploy.sh init mon-projet"
    echo "  3. Le script vous guidera pour:"
    echo "     - Créer le dépôt GitHub automatiquement"
    echo "     - Déployer sur Render et Netlify"
    echo "     - Configurer le CI/CD"
    echo ""
    print_info "Pour l'aide: ./deploy.sh help"
}

main "$@"