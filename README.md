# StackBuild

Starter kit complet pour applications web avec **Spring Boot**, **Angular** et **PostgreSQL**, orchestré via Docker.

## Fonctionnalités actuelles

- ✅ Backend Spring Boot (JDK 17) dans un conteneur Docker.
- ✅ Frontend Angular dans un conteneur Nginx.
- ✅ Base de données PostgreSQL persistante.
- ✅ Orchestration avec `docker-compose.yml`.
- ✅ Script d’automatisation `deploy.sh` pour lancer tout en une commande.

## Usage

1. Clonez le dépôt.
2. Lancer un Docker Enginer (par exemple Docker Desktop sur Windows)
3. Lancez :
   ```bash
   bash deploy.sh

Accédez à :
- Frontend : http://localhost:4200
- Backend : http://localhost:8080
- Base de données : localhost:5432 (via client SQL)

## Prochaines étapes

- 🔜 Déploiement automatique sur Netlify (front) et Render (back + DB).
- 🔜 Support multi-stack (MERN, Django, etc.).
- 🔜 Sécurité renforcée (JWT, rôles).
- 🔜 Monitoring et gestion des environnements (dev, prod).

## Technos

- Spring Boot 3.5
- Angular 18
- PostgreSQL 15
- Docker & Docker Compose


Un starter cloud pour développeurs, simple, rapide et prêt à l’emploi.


