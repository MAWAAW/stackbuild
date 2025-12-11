#!/bin/bash

# Script de déploiement sur Render

deploy_to_render() {
    print_info "Déploiement du backend sur Render..."
    
    # Vérifier si le token Render est configuré
    if [ -z "$RENDER_API_KEY" ]; then
        print_warning "RENDER_API_KEY non défini"
        print_info "Pour déployer automatiquement, configurez votre clé API Render:"
        echo "  export RENDER_API_KEY=your_api_key"
        echo ""
        print_info "Ou utilisez le déploiement manuel:"
        show_render_manual_steps
        return
    fi
    
    # Détecter le type de backend
    local backend_type=$(detect_backend_type)
    
    # Créer le service Render
    create_render_service "$backend_type"
}

detect_backend_type() {
    if [ -f "backend/pom.xml" ]; then
        echo "spring"
    elif [ -f "backend/package.json" ]; then
        echo "node"
    elif [ -f "backend/requirements.txt" ]; then
        echo "fastapi"
    else
        echo "unknown"
    fi
}

create_render_service() {
    local backend_type=$1
    local project_name=$(basename $(pwd))
    
    print_info "  Création du service Render pour $backend_type..."
    
    # Préparer le blueprint Render
    cat > "render.yaml" << EOF
services:
  - type: web
    name: ${project_name}-backend
    env: docker
    region: frankfurt
    plan: free
    branch: main
    dockerfilePath: ./backend/Dockerfile
    envVars:
      - key: DATABASE_URL
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: CORS_ORIGINS
        value: https://${project_name}-frontend.netlify.app
    healthCheckPath: /api/health

databases:
  - name: ${project_name}-db
    databaseName: appdb
    user: appuser
    plan: free
    region: frankfurt
EOF
    
    print_success "  Fichier render.yaml créé"
    
    # Proposer de créer le service via l'API
    create_via_api "$project_name"
}

create_via_api() {
    local project_name=$1
    
    print_info "  Création du service via l'API Render..."
    
    # Vérifier si un repo Git est configuré
    if ! git remote get-url origin &>/dev/null; then
        print_warning "Aucun dépôt Git distant configuré"
        print_info "Veuillez d'abord pousser votre code sur GitHub/GitLab"
        show_git_setup_instructions
        return
    fi
    
    local repo_url=$(git remote get-url origin)
    
    # Créer le service Web
    local response=$(curl -s -X POST \
        "https://api.render.com/v1/services" \
        -H "Authorization: Bearer $RENDER_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "type": "web_service",
          "name": "'"$project_name"'-backend",
          "ownerId": "'"$RENDER_OWNER_ID"'",
          "repo": "'"$repo_url"'",
          "autoDeploy": true,
          "branch": "main",
          "dockerfilePath": "./backend/Dockerfile",
          "envVars": [
            {
              "key": "JWT_SECRET",
              "generateValue": true
            }
          ],
          "region": "frankfurt",
          "plan": "free"
        }')
    
    if echo "$response" | grep -q '"id"'; then
        local service_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        local service_url=$(echo "$response" | grep -o '"serviceUrl":"[^"]*"' | cut -d'"' -f4)
        
        print_success "  Service créé avec succès!"
        print_info "  Service ID: $service_id"
        print_info "  URL: $service_url"
        
        # Sauvegarder les infos
        cat > ".render-info" << EOF
SERVICE_ID=$service_id
SERVICE_URL=$service_url
DEPLOY_HOOK=https://api.render.com/deploy/$service_id?key=...
EOF
        
        print_info "  Informations sauvegardées dans .render-info"
    else
        print_error "  Échec de la création du service"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        show_render_manual_steps
    fi
}

show_render_manual_steps() {
    cat << 'EOF'

📋 Étapes de déploiement manuel sur Render:

1. Allez sur https://dashboard.render.com
2. Cliquez sur "New +" > "Web Service"
3. Connectez votre dépôt Git (GitHub/GitLab)
4. Configurez le service:
   - Name: votre-projet-backend
   - Region: Frankfurt (EU)
   - Branch: main
   - Root Directory: ./backend
   - Environment: Docker
   - Dockerfile Path: ./backend/Dockerfile
   - Plan: Free

5. Ajoutez les variables d'environnement:
   - JWT_SECRET (générer une valeur aléatoire)
   - DATABASE_URL (sera fournie par Render si vous créez une DB)
   - CORS_ORIGINS (URL de votre frontend Netlify)

6. Créez aussi une base de données PostgreSQL:
   - New + > PostgreSQL
   - Name: votre-projet-db
   - Plan: Free
   - Region: Frankfurt

7. Liez la base au service web en ajoutant DATABASE_URL

8. Copiez le Deploy Hook pour GitHub Actions:
   - Settings > Deploy Hook
   - Ajoutez-le comme secret RENDER_DEPLOY_HOOK_BACKEND

EOF
}

show_git_setup_instructions() {
    cat << 'EOF'

📦 Configuration Git requise:

1. Créez un dépôt sur GitHub:
   gh repo create votre-projet --public --source=. --remote=origin

2. Ou manuellement:
   - Allez sur github.com et créez un nouveau repo
   - Ajoutez le remote:
     git remote add origin https://github.com/votre-username/votre-projet.git

3. Poussez votre code:
   git add .
   git commit -m "Initial commit"
   git push -u origin main

4. Relancez le déploiement:
   ./deploy.sh deploy --backend-only

EOF
}

# Fonction pour obtenir les logs de déploiement
get_render_deploy_logs() {
    local service_id=$1
    
    if [ -z "$RENDER_API_KEY" ]; then
        print_error "RENDER_API_KEY non configuré"
        return
    fi
    
    curl -s "https://api.render.com/v1/services/$service_id/deploys?limit=1" \
        -H "Authorization: Bearer $RENDER_API_KEY" | jq '.'
}

# Fonction pour vérifier le statut du service
check_render_service_status() {
    if [ ! -f ".render-info" ]; then
        print_warning "Fichier .render-info introuvable"
        return
    fi
    
    source .render-info
    
    if [ -z "$SERVICE_ID" ]; then
        print_error "SERVICE_ID non trouvé dans .render-info"
        return
    fi
    
    print_info "Vérification du statut du service..."
    
    local response=$(curl -s "https://api.render.com/v1/services/$SERVICE_ID" \
        -H "Authorization: Bearer $RENDER_API_KEY")
    
    local status=$(echo "$response" | jq -r '.service.state')
    local url=$(echo "$response" | jq -r '.service.serviceDetails.url')
    
    print_info "Status: $status"
    print_info "URL: $url"
    
    if [ "$status" = "live" ]; then
        print_success "✓ Service actif et accessible"
        print_info "Testez votre API: curl $url/api/health"
    else
        print_warning "Service en cours de déploiement..."
    fi
}