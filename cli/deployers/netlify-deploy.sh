#!/bin/bash

# Script de déploiement sur Netlify

deploy_to_netlify() {
    print_info "Déploiement du frontend sur Netlify..."
    
    # Vérifier qu'on est dans un projet
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Fichier docker-compose.yml introuvable"
        return 1
    fi
    
    local project_name=$(basename $(pwd))
    
    # Vérifier si netlify-cli est installé
    if ! command -v netlify &> /dev/null; then
        print_warning "Netlify CLI n'est pas installé"
        
        read -p "Installer Netlify CLI maintenant? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            print_info "Installation de Netlify CLI..."
            npm install -g netlify-cli
            print_success "Netlify CLI installé"
        else
            show_netlify_manual_steps
            return 1
        fi
    fi
    
    # Vérifier l'authentification
    if ! netlify status &> /dev/null 2>&1; then
        print_info "Authentification Netlify requise..."
        netlify login
    fi
    
    # Détecter le type de frontend
    local frontend_type=$(detect_frontend_type)
    print_info "Frontend détecté: $frontend_type"
    
    # Récupérer l'URL du backend si disponible
    local backend_url=""
    if [ -f ".render-info" ]; then
        source .render-info
        backend_url="$SERVICE_URL"
        print_info "Backend URL: $backend_url"
    else
        print_warning "Backend URL non trouvée, utilisation de localhost"
        backend_url="http://localhost:8080"
    fi
    
    # Build le frontend avec la bonne URL d'API
    build_frontend_with_env "$frontend_type" "$backend_url"
    
    # Déployer sur Netlify
    deploy_frontend_auto "$frontend_type" "$project_name"
}

build_frontend_with_env() {
    local frontend_type=$1
    local backend_url=$2
    
    print_info "Build du frontend avec API URL: $backend_url..."
    
    cd frontend
    
    # Créer le fichier .env pour le build
    cat > .env << EOF
VITE_API_URL=${backend_url}/api
REACT_APP_API_URL=${backend_url}/api
VUE_APP_API_URL=${backend_url}/api
EOF
    
    # Installer les dépendances si nécessaire
    if [ ! -d "node_modules" ]; then
        print_info "Installation des dépendances..."
        npm install
    fi
    
    # Build selon le type
    print_info "Build en cours..."
    case $frontend_type in
        angular)
            npm run build -- --configuration production
            ;;
        react)
            npm run build
            ;;
        vue)
            npm run build
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "Build réussi"
        
        # Afficher le contenu de dist pour debug
        print_info "Contenu du dossier dist:"
        ls -la dist/
        
        if [ -d "dist" ]; then
            print_info "Sous-dossiers de dist:"
            find dist -type d -maxdepth 2
        fi
    else
        print_error "Échec du build"
        cd ..
        return 1
    fi
    
    cd ..
}

deploy_frontend_auto() {
    local frontend_type=$1
    local project_name=$2
    
    print_info "Déploiement automatique sur Netlify..."
    
    cd frontend
    
    # Déterminer le dossier de build
    local build_dir=$(get_build_directory "$frontend_type")
    
    if [ ! -d "$build_dir" ]; then
        print_error "Dossier de build introuvable: $build_dir"
        cd ..
        return 1
    fi
    
    print_info "Dossier de build: $build_dir"
    
    # Déployer avec création automatique du site
    print_info "Déploiement en cours..."
    
    local deploy_output=$(netlify deploy --prod --dir="$build_dir" --json 2>&1)
    
    if echo "$deploy_output" | jq -e '.site_id' &> /dev/null; then
        local site_id=$(echo "$deploy_output" | jq -r '.site_id')
        local deploy_url=$(echo "$deploy_output" | jq -r '.deploy_url')
        local site_url=$(echo "$deploy_output" | jq -r '.url')
        
        print_success "Frontend déployé avec succès!"
        print_info "Site ID: $site_id"
        print_info "Deploy URL: $deploy_url"
        print_info "Site URL: $site_url"
        
        # Sauvegarder les infos
        cat >> "../.netlify-info" << EOF
NETLIFY_SITE_ID=$site_id
NETLIFY_URL=$site_url
DEPLOY_URL=$deploy_url
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
        
        print_success "Informations sauvegardées dans .netlify-info"
        
        # Mettre à jour CORS du backend si possible
        update_backend_cors "$site_url"
        
        # Instructions pour GitHub Actions
        print_info ""
        print_info "Pour GitHub Actions, configurez ces secrets:"
        echo "  gh secret set NETLIFY_AUTH_TOKEN"
        echo "  gh secret set NETLIFY_SITE_ID --body=\"$site_id\""
        echo "  gh secret set API_URL --body=\"\$SERVICE_URL/api\""
        
    else
        print_error "Échec du déploiement"
        echo "$deploy_output"
        
        # Essayer sans --json pour avoir plus de détails
        print_info "Nouvelle tentative avec plus de détails..."
        netlify deploy --prod --dir="$build_dir"
    fi
    
    cd ..
}

detect_frontend_type() {
    if [ -f "frontend/angular.json" ]; then
        echo "angular"
    elif [ -f "frontend/package.json" ]; then
        local package_json=$(cat frontend/package.json)
        if echo "$package_json" | grep -q "react"; then
            echo "react"
        elif echo "$package_json" | grep -q "vue"; then
            echo "vue"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

build_frontend() {
    local frontend_type=$1
    
    print_info "  Build du frontend ($frontend_type)..."
    
    cd frontend
    
    # Installer les dépendances si nécessaire
    if [ ! -d "node_modules" ]; then
        print_info "  Installation des dépendances..."
        npm install
    fi
    
    # Configurer les variables d'environnement
    if [ -f ".render-info" ]; then
        source ../.render-info
        export VITE_API_URL="$SERVICE_URL/api"
        export REACT_APP_API_URL="$SERVICE_URL/api"
    fi
    
    # Build selon le type
    case $frontend_type in
        angular)
            npm run build -- --configuration production
            ;;
        react)
            npm run build
            ;;
        vue)
            npm run build
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "  Build réussi"
    else
        print_error "  Échec du build"
        exit 1
    fi
    
    cd ..
}

deploy_frontend() {
    local frontend_type=$1
    local project_name=$(basename $(pwd))
    
    print_info "  Déploiement sur Netlify..."
    
    cd frontend
    
    # Déterminer le dossier de build
    local build_dir=$(get_build_directory "$frontend_type")
    
    if [ ! -d "$build_dir" ]; then
        print_error "Dossier de build introuvable: $build_dir"
        exit 1
    fi
    
    # Déployer
    if [ -n "$NETLIFY_SITE_ID" ]; then
        # Site existant
        netlify deploy --prod --dir="$build_dir" --site="$NETLIFY_SITE_ID"
    else
        # Nouveau site
        print_info "  Création d'un nouveau site Netlify..."
        
        local response=$(netlify deploy --prod --dir="$build_dir" --json)
        
        if echo "$response" | grep -q '"site_id"'; then
            local site_id=$(echo "$response" | jq -r '.site_id')
            local deploy_url=$(echo "$response" | jq -r '.deploy_url')
            local site_url=$(echo "$response" | jq -r '.url')
            
            print_success "  Frontend déployé avec succès!"
            print_info "  Site ID: $site_id"
            print_info "  Deploy URL: $deploy_url"
            print_info "  Site URL: $site_url"
            
            # Sauvegarder les infos
            cat >> "../.netlify-info" << EOF
NETLIFY_SITE_ID=$site_id
NETLIFY_URL=$site_url
DEPLOY_URL=$deploy_url
EOF
            
            print_info "  Informations sauvegardées dans .netlify-info"
            
            # Mise à jour de la config CORS du backend
            update_backend_cors "$site_url"
        else
            print_error "  Échec du déploiement"
            echo "$response"
        fi
    fi
    
    cd ..
}

get_build_directory() {
    local frontend_type=$1
    
    case $frontend_type in
        angular)
            # Méthode 1 : Chercher dist/*/browser avec find
            local browser_dir=$(find dist -type d -name "browser" 2>/dev/null | head -1)
            if [ -n "$browser_dir" ] && [ -d "$browser_dir" ]; then
                echo "$browser_dir"
                return 0
            fi
            
            # Méthode 2 : Lire angular.json
            if [ -f "angular.json" ]; then
                local project_name=$(grep -oP '"projects"\s*:\s*\{[^}]*"([^"]+)"' angular.json | grep -oP '"[^"]+"' | sed -n '2p' | tr -d '"')
                if [ -n "$project_name" ] && [ -d "dist/$project_name/browser" ]; then
                    echo "dist/$project_name/browser"
                    return 0
                fi
            fi
            
            # Méthode 3 : Parcourir dist/*/browser
            for dir in dist/*/browser; do
                if [ -d "$dir" ]; then
                    echo "$dir"
                    return 0
                fi
            done
            
            # Fallback : dist/browser (Angular standalone)
            if [ -d "dist/browser" ]; then
                echo "dist/browser"
                return 0
            fi
            
            # Dernier recours
            echo "dist"
            ;;
        react)
            echo "build"
            ;;
        vue)
            echo "dist"
            ;;
        *)
            echo "dist"
            ;;
    esac
}

update_backend_cors() {
    local frontend_url=$1
    
    print_info "  Mise à jour de la configuration CORS..."
    
    if [ -f ".render-info" ]; then
        source .render-info
        
        if [ -n "$SERVICE_ID" ] && [ -n "$RENDER_API_KEY" ]; then
            # Mettre à jour la variable CORS_ORIGINS via l'API Render
            curl -s -X PUT \
                "https://api.render.com/v1/services/$SERVICE_ID/env-vars/CORS_ORIGINS" \
                -H "Authorization: Bearer $RENDER_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"value\": \"$frontend_url\"}" > /dev/null
            
            print_success "  Configuration CORS mise à jour"
            print_info "  Le backend acceptera les requêtes de: $frontend_url"
        fi
    fi
}

# Configuration du domaine personnalisé
configure_custom_domain() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        print_error "Nom de domaine requis"
        return
    fi
    
    print_info "Configuration du domaine personnalisé: $domain"
    
    cd frontend
    netlify domains:add "$domain"
    
    print_info "Configurez vos DNS avec les paramètres suivants:"
    netlify domains:show
    
    cd ..
}

# Fonction pour afficher les instructions manuelles
show_netlify_manual_steps() {
    cat << 'EOF'

📋 Déploiement manuel sur Netlify:

1. Installez Netlify CLI:
   npm install -g netlify-cli

2. Authentifiez-vous:
   netlify login

3. Allez dans le dossier frontend:
   cd frontend

4. Déployez:
   netlify deploy --prod

   Ou créez un nouveau site:
   netlify init

5. Pour connecter à GitHub (déploiement automatique):
   - Allez sur https://app.netlify.com
   - Sites > Add new site > Import from Git
   - Sélectionnez votre dépôt
   - Configuration:
     * Base directory: frontend
     * Build command: npm run build
     * Publish directory: dist/[project-name]/browser (Angular)
                          ou build (React)
                          ou dist (Vue)

6. Configurez les variables d'environnement:
   - Site settings > Environment variables
   - Ajoutez: VITE_API_URL (ou REACT_APP_API_URL)
   - Valeur: URL de votre backend Render

7. Récupérez votre Site ID pour GitHub Actions:
   - Site settings > General > Site details
   - Copiez le Site ID
   - Ajoutez-le comme secret GitHub: NETLIFY_SITE_ID

8. Créez un Access Token pour CI/CD:
   - User settings > Applications > Personal access tokens
   - New access token
   - Ajoutez-le comme secret GitHub: NETLIFY_AUTH_TOKEN

EOF
}

# Fonction pour obtenir les infos du site
get_netlify_site_info() {
    if [ ! -f ".netlify-info" ]; then
        print_warning "Fichier .netlify-info introuvable"
        return
    fi
    
    source .netlify-info
    
    if [ -z "$NETLIFY_SITE_ID" ]; then
        print_error "NETLIFY_SITE_ID non trouvé"
        return
    fi
    
    print_info "Informations du site Netlify:"
    cd frontend
    netlify status --site="$NETLIFY_SITE_ID"
    cd ..
}

# Fonction pour voir les logs de build
get_netlify_deploy_logs() {
    if [ ! -f ".netlify-info" ]; then
        print_warning "Fichier .netlify-info introuvable"
        return
    fi
    
    source .netlify-info
    
    cd frontend
    netlify logs --site="$NETLIFY_SITE_ID"
    cd ..
}

# Rollback vers un déploiement précédent
rollback_netlify_deploy() {
    if [ ! -f ".netlify-info" ]; then
        print_warning "Fichier .netlify-info introuvable"
        return
    fi
    
    source .netlify-info
    
    print_info "Liste des déploiements précédents:"
    cd frontend
    netlify deploys:list --site="$NETLIFY_SITE_ID"
    
    read -p "ID du déploiement à restaurer: " deploy_id
    
    if [ -n "$deploy_id" ]; then
        netlify deploy:restore --deploy="$deploy_id" --site="$NETLIFY_SITE_ID"
        print_success "Déploiement restauré"
    fi
    
    cd ..
}