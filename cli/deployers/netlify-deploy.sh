#!/bin/bash

# Script de déploiement sur Netlify

deploy_to_netlify() {
    print_info "Déploiement du frontend sur Netlify..."
    
    # Vérifier si netlify-cli est installé
    if ! command -v netlify &> /dev/null; then
        print_warning "Netlify CLI n'est pas installé"
        print_info "Installation de Netlify CLI..."
        npm install -g netlify-cli
    fi
    
    # Vérifier l'authentification
    if [ -z "$NETLIFY_AUTH_TOKEN" ]; then
        print_info "Authentification Netlify requise..."
        netlify login
    fi
    
    # Détecter le type de frontend
    local frontend_type=$(detect_frontend_type)
    
    # Build le frontend
    build_frontend "$frontend_type"
    
    # Déployer sur Netlify
    deploy_frontend "$frontend_type"
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
            # Angular met les fichiers dans dist/[project-name]/browser
            local project_name=$(cat angular.json | jq -r '.projects | keys[0]')
            echo "dist/$project_name/browser"
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