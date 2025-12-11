#!/bin/bash

# Script de diagnostic pour identifier les problèmes

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Diagnostic Web Stack CLI        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

# 1. Vérifier Docker
print_info "1. Vérification de Docker..."
if command -v docker &> /dev/null; then
    print_success "Docker installé: $(docker --version)"
    
    if docker ps &> /dev/null; then
        print_success "Docker daemon en cours d'exécution"
    else
        print_error "Docker daemon ne répond pas"
        echo "   Lancez Docker Desktop ou démarrez le daemon"
        exit 1
    fi
else
    print_error "Docker n'est pas installé"
    exit 1
fi
echo ""

# 2. Vérifier les conteneurs
print_info "2. État des conteneurs..."
if [ -f "docker-compose.yml" ]; then
    docker-compose ps
    echo ""
    
    # Vérifier chaque service
    for service in db backend frontend; do
        if docker-compose ps | grep -q "$service.*Up"; then
            print_success "$service: démarré"
        else
            print_warning "$service: non démarré ou en erreur"
        fi
    done
else
    print_warning "Aucun docker-compose.yml trouvé dans ce répertoire"
fi
echo ""

# 3. Vérifier les ports
print_info "3. Vérification des ports..."
check_port() {
    local port=$1
    local service=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t &> /dev/null; then
        local pid=$(lsof -Pi :$port -sTCP:LISTEN -t)
        local process=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
        print_success "Port $port ($service): utilisé par $process (PID: $pid)"
    else
        print_warning "Port $port ($service): libre (service non démarré?)"
    fi
}

check_port 5432 "PostgreSQL"
check_port 8080 "Backend"
check_port 4200 "Frontend"
echo ""

# 4. Tester la connectivité
print_info "4. Tests de connectivité..."

# PostgreSQL
if docker-compose ps | grep -q "db.*Up"; then
    if docker-compose exec -T db psql -U appuser -d appdb -c "SELECT 1" &> /dev/null; then
        print_success "PostgreSQL: connecté et opérationnel"
    else
        print_error "PostgreSQL: démarré mais ne répond pas"
        echo "   Logs: docker-compose logs db"
    fi
else
    print_warning "PostgreSQL: non démarré"
fi

# Backend
if curl -s http://localhost:8080/api/health &> /dev/null; then
    response=$(curl -s http://localhost:8080/api/health)
    print_success "Backend: accessible sur http://localhost:8080"
    echo "   Réponse: $response"
else
    print_error "Backend: inaccessible sur http://localhost:8080"
    if docker-compose ps | grep -q "backend.*Up"; then
        print_info "   Le conteneur tourne, vérifiez les logs:"
        echo "   docker-compose logs backend | tail -50"
    else
        print_info "   Le conteneur n'est pas démarré"
    fi
fi

# Frontend
if curl -s http://localhost:4200 &> /dev/null; then
    print_success "Frontend: accessible sur http://localhost:4200"
else
    print_error "Frontend: inaccessible sur http://localhost:4200"
fi
echo ""

# 5. Vérifier les logs pour erreurs communes
print_info "5. Recherche d'erreurs dans les logs..."
if [ -f "docker-compose.yml" ]; then
    echo ""
    print_info "Dernières erreurs du backend:"
    docker-compose logs backend 2>&1 | grep -i "error\|exception\|failed" | tail -5 || echo "   Aucune erreur récente"
    
    echo ""
    print_info "Dernières erreurs de la DB:"
    docker-compose logs db 2>&1 | grep -i "error\|fatal" | tail -5 || echo "   Aucune erreur récente"
fi
echo ""

# 6. Vérifier la configuration
print_info "6. Vérification de la configuration..."
if [ -f "backend/src/main/resources/application.yml" ]; then
    db_url=$(grep "url:" backend/src/main/resources/application.yml | head -1)
    if echo "$db_url" | grep -q "localhost"; then
        print_error "Configuration DB: utilise 'localhost' au lieu de 'db'"
        echo "   Changez jdbc:postgresql://localhost en jdbc:postgresql://db"
    else
        print_success "Configuration DB: correcte (utilise 'db' comme host)"
    fi
else
    print_warning "application.yml non trouvé"
fi
echo ""

# 7. Recommandations
print_info "7. Recommandations..."
echo ""

if ! docker-compose ps | grep -q "backend.*Up"; then
    echo "🔧 Le backend n'est pas démarré. Essayez:"
    echo "   docker-compose up -d db"
    echo "   # Attendez 10 secondes"
    echo "   docker-compose up backend"
    echo ""
fi

if docker-compose logs backend 2>&1 | grep -q "Connection.*refused"; then
    echo "🔧 Erreur de connexion DB détectée. Solutions:"
    echo "   1. Vérifiez que PostgreSQL est démarré: docker-compose up -d db"
    echo "   2. Vérifiez le hostname dans application.yml (doit être 'db')"
    echo "   3. Attendez que PostgreSQL soit prêt (healthcheck)"
    echo ""
fi

if docker-compose logs backend 2>&1 | grep -q "Port 8080.*already in use"; then
    echo "🔧 Port 8080 déjà utilisé. Libérez-le:"
    echo "   sudo lsof -ti:8080 | xargs kill -9"
    echo ""
fi

echo "📋 Commandes utiles:"
echo "   docker-compose logs backend      # Voir les logs du backend"
echo "   docker-compose logs -f backend   # Suivre les logs en temps réel"
echo "   docker-compose restart backend   # Redémarrer le backend"
echo "   docker-compose down -v           # Tout arrêter et nettoyer"
echo "   docker-compose up --build        # Reconstruire et relancer"
echo ""

echo "✅ Diagnostic terminé!"